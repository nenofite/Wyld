module wyld.worldgen;

import wyld.main;
import wyld.format;

import std.random: uniform;
import std.stdio;

World genWorld(int w, int h) {
  auto biomes = new Grid!(Biome)(w, h);
  biomes.map((Biome a) {
    int r = uniform(0, 100);
    if (r < 40) return Biome(Biome.GRASS);
    else if (r < 65) return Biome(Biome.FOREST);
    else if (r < 75) return Biome(Biome.JUNGLE);
    else if (r < 85) return Biome(Biome.MARSH);
    else return Biome(Biome.MOUNTAIN);
  });
  biomes = subdiv(subdiv(subdiv(biomes)));
  
  auto geos = biomes.mapT((Biome b) {
    if (uniform(0, 100) == 0) return Geo(Geo.WATER);
    switch (b.type) {
      case Biome.GRASS:
        if (uniform(0, 100) == 0) return Geo(Geo.ROCK);
        else return Geo(Geo.GRASS);
      case Biome.FOREST:
        if (uniform(0, 100) == 0) return Geo(Geo.GRASS);
        else return Geo(Geo.FOREST);
      case Biome.JUNGLE:
        return Geo(Geo.FOREST);  //TODO add Jungle Geo
      case Biome.MARSH:
        if (uniform(0, 100) == 0) return Geo(Geo.GRASS);
        else return Geo(Geo.MARSH);
      case Biome.MOUNTAIN:
        return Geo(Geo.ROCK);
      default:
        throw new Error(format("No Terr for Biome %d", b));
    }
  });
  geos = subdiv(subdiv(geos));
  
  World world = new World();

  world.stat = geos.mapT((Geo g) {
    Terr.Type t;
  
    switch (g.type) {
      case Geo.WATER:
        t = Terr.WATER;
        break;
      case Geo.ROCK:
        t = Terr.ROCK;
        break;
      case Geo.GRASS:
      case Geo.FOREST:
        t = Terr.DIRT;
        break;
      case Geo.MARSH:
        t = Terr.MUD;
        break;
      default:
        throw new Error(format("Cannot convert to Terr: %d", g));
        break;
    }
    
    return World.StatCont(terr(t));
  });
  
  for (int y = 0; y < geos.h; y += 3) {
    for (int x = 0; x < geos.w; x += 3) {
      if (geos.get(x, y).type == Geo.FOREST) {
        while (true) {
          int xd = x + uniform(-1, 1),
              yd = y + uniform(-1, 1);
          if (geos.inside(xd, yd) && !world.blockAt(xd, yd)) {
            world.addStatEnt(new Tree(xd, yd));
            break;
          }
        }
      }
    }
  }
  
  for (int y = 0; y < geos.h; y++) {
    for (int x = 0; x < geos.w; x++) {
      auto a = geos.get(x, y);
      if (a.type == Geo.FOREST || a.type == Geo.GRASS) {
        if (uniform(0, 50) != 0) {
          if (!world.blockAt(x, y)) {
            world.addStatEnt(new Grass(x, y));
          }
        }
      }
    }
  }
  
  return world;
}

struct Biome {
  enum Type {
    GRASS,
    FOREST,
    JUNGLE,
    MARSH,
    MOUNTAIN
  }
  alias Type this;
  
  Type type;
}

struct Geo {
  enum Type {
    WATER,
    ROCK,
    GRASS,
    FOREST,
    MARSH
  }
  alias Type this;
  
  Type type;
}
    
Grid!(A) subdiv(A)(Grid!(A) old) {
  auto grid = new Grid!(A)(old.w * 2 - 1, old.h * 2 - 1);

  for (int y = 0; y < grid.h; y += 2) {
    for (int x = 0; x < grid.w; x += 2) {
      grid.set(x, y, old.get(x / 2, y / 2));
    }
  }

  for (int y = 1; y < grid.h; y += 2) {
    for (int x = 1; x < grid.w; x += 2) {
      A[4] options = [
        grid.get(x - 1, y - 1),
        grid.get(x + 1, y - 1),
        grid.get(x - 1, y + 1),
        grid.get(x + 1, y + 1)
      ];
      grid.set(x, y, options[uniform(0, 4)]);
    }
  }
  
  for (int y = 0; y < grid.h; y++) {
    for (int x = y % 2 == 0 ? 1 : 0; x < grid.w; x += 2) {
      A[] options;
      if (grid.inside(x, y - 1)) options ~= grid.get(x, y - 1);
      if (grid.inside(x + 1, y)) options ~= grid.get(x + 1, y);
      if (grid.inside(x, y + 1)) options ~= grid.get(x, y + 1);
      if (grid.inside(x - 1, y)) options ~= grid.get(x - 1, y);
      
      grid.set(x, y, options[uniform(0, options.length)]);
    }
  }
  
  return grid;
}
