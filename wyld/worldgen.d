module wyld.worldgen;

import wyld.main;
import wyld.format;

import std.random: uniform;
import std.stdio;

World genWorld(int w, int h) {
  int msgY = 0;
  n.attrset(n.COLOR_PAIR(Col.TEXT));
  void msg(string m) {
    n.mvprintw(++msgY, 2, toStringz(m));
    n.refresh();
  }
  
  auto biomes = new Grid!(Biome)(w, h);
  biomes.map((Biome a) {
    int r = uniform(0, 100);
    if (r < 40) return Biome(Biome.GRASS);
    else if (r < 65) return Biome(Biome.FOREST);
    else if (r < 75) return Biome(Biome.JUNGLE);
    else if (r < 85) return Biome(Biome.MARSH);
    else if (r < 95) return Biome(Biome.LAKE);
    else return Biome(Biome.MOUNTAIN);
  });
  msg("Biomes generated.");
  biomes = subdiv(subdiv(subdiv(biomes)));
  msg("Biomes subdivided.");
  
  auto geos = biomes.mapT((Biome b) {
    if (uniform(0, 1000) == 0) return Geo(Geo.WATER);
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
      case Biome.LAKE:
        return Geo(Geo.WATER);
      case Biome.MOUNTAIN:
        return Geo(Geo.ROCK);
      default:
        throw new Error(format("No Terr for Biome %d", b));
    }
  });
  msg("Biomes converted to Geos.");

  
  World world = new World();
  world.geos = geos.dup;
  msg("World created, map copied.");
  for (int i = 0; i < geoSubd; i++) {
    geos = subdiv(geos);
  }
  msg("Geos subdivided.");

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
  msg("Geos converted to StatCont grid.");
  
  {
    int rx = uniform(world.stat.w / 4, world.stat.w * 3 / 4);
    for (int ry = 0; ry < world.stat.h; ry++) {
      if (world.geos.inside(world.xToGeo(rx), world.yToGeo(ry)))
        world.geos.set(world.xToGeo(rx), world.yToGeo(ry), Geo(Geo.WATER));
      for (int xd = 0; xd < 3; xd++)
        world.stat.set(rx + xd, ry, World.StatCont(terr(Terr.WATER)));
      if (ry % 5 == 0)
        rx += uniform(-1, 2);
    }
  }
  msg("River generated.");
  
  for (int y = 0; y < geos.h; y += 3) {
    for (int x = 0; x < geos.w; x += 3) {
      if (geos.get(x, y).type == Geo.FOREST) {
        for (int tries = 0; tries < 10; tries++) {
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
  msg("Trees generated.");
  
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
  msg("Grass generated.");
  
  msg("Worldgen done.");
  return world;
}

struct Biome {
  enum Type {
    GRASS,
    FOREST,
    JUNGLE,
    MARSH,
    LAKE,
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
  bool discovered;
  
  Sym sym() const {
    switch (type) {
      case WATER:
        return Sym('~', Col.BLUE);
      case ROCK:
        return Sym('-', Col.WHITE);
      case GRASS:
        return Sym('"', Col.GREEN);
      case FOREST:
        return Sym('t', Col.GREEN);
      case MARSH:
        return Sym('=', Col.YELLOW);
      default:
        throw new Error(format("No sym for Geo %d", type));
    }
  }
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
