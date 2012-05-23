module wyld.worldgen;

import wyld.main;
import wyld.format;

import std.random: uniform;
import std.stdio;

class WorldGen {
  Grid!(Geo) grid;
  
  this(int w, int h) {
    grid = new Grid!(Geo)(w, h);
  }

  struct Geo {
    enum Type {
      WATER,
      ROCK,
      GRASS,
      FOREST,
      MARSH
    }
    
    Type type;
    
    int spreadChance() const {
      switch (type) {
        case Type.WATER:
          return 80;
        case Type.FOREST:
        case Type.MARSH:
          return 75;
        default:
          return 50;
      }
    }
    
    Terr toTerr() const {
      switch (type) {
        case Type.WATER:
          return Terr(Terr.Type.WATER);
          break;
        case Type.ROCK:
          return Terr(Terr.Type.ROCK);
          break;
        case Type.GRASS:
        case Type.FOREST:
          return Terr(Terr.Type.DIRT);
          break;
        case Type.MARSH:
          return Terr(Terr.Type.MUD);
          break;
        default:
          throw new Error(format("Cannot convert to Terr: %d", type));
          break;
      }
    }
    
    static Geo random() {
      Geo ret;
      if (uniform(0, 100) <= 2) {
        ret.type = Geo.Type.WATER;
      } else if (uniform(0, 100) <= 2) {
        ret.type = Geo.Type.ROCK;
      } else if (uniform(0, 100) <= 50) {
        ret.type = Geo.Type.GRASS;
      } else if (uniform(0, 100) <= 25) {
        ret.type = Geo.Type.FOREST;
      } else if (uniform(0, 100) <= 2) {
        ret.type = Geo.Type.MARSH;
      } else {
        ret.type = Geo.Type.GRASS;
      }
      return ret;
    }
    
    static Geo interp(Geo a, Geo b) {
      if (a.spreadChance() > b.spreadChance()) {
        if (uniform(0, 100) <= a.spreadChance()) {
          return a;
        } else {
          return b;
        }
      } else {
        if (uniform(0, 100) <= b.spreadChance()) {
          return b;
        } else {
          return a;
        }
      }
    }
  }
  
  void fillNoise(/*ref Grid!(Geo) grid*/) {
    for (int y = 0; y < grid.h; y++) {
      for (int x = 0; x < grid.w; x++) {
        grid.set(x, y, Geo.random());
      }
    }
  }
  
  void subd(/*ref Grid!(Geo) grid*/) {
    auto old = grid;
    grid = new Grid!(Geo)(old.w * 2 - 1, old.h * 2 - 1);

    for (int y = 0; y < grid.h; y += 2) {
      for (int x = 0; x < grid.w; x += 2) {
        grid.set(x, y, old.get(x / 2, y / 2));
      }
    }

    for (int y = 1; y < grid.h; y += 2) {
      for (int x = 1; x < grid.w; x += 2) {
        Geo[4] options = [
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
        Geo[] options;
        if (grid.inside(x, y - 1)) options ~= grid.get(x, y - 1);
        if (grid.inside(x + 1, y)) options ~= grid.get(x + 1, y);
        if (grid.inside(x, y + 1)) options ~= grid.get(x, y + 1);
        if (grid.inside(x - 1, y)) options ~= grid.get(x - 1, y);
        
        grid.set(x, y, options[uniform(0, options.length)]);
      }
    }
  }
  
  Grid!(Terr) toTerrs() {
    auto ret = new Grid!(Terr)(grid.w, grid.h);
    for (int y = 0; y < grid.h; y++) {
      for (int x = 0; x < grid.w; x++) {
        ret.set(x, y, grid.get(x, y).toTerr());
      }
    }
    return ret;
  }
}
