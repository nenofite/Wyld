/// Contains the data structure of the in-game world
module wyld.core.world;

import wyld.core.common;
import wyld.core.ent;
import wyld.ent;
import wyld.main;

import alg = std.algorithm;
import math = std.math;
import std.string: format;

/// The current game world, available for easy access
World world;


/// Contains the terrain, ents, map, time, etc. of the in-game world
class World {
  DynamicEnt[] dynamicEnts; /// The Ents that need updating
  Grid!StaticContents staticGrid;    /// A grid of static terrain, ents, and tracks
  Grid!MapContents map;    /// The map of the world, used for map screen and minimap
  Time time;  /// The in-game time
  
  this(DynamicEnt[] dynamicEnts, Grid!StaticContents staticGrid, Grid!MapContents map, Time time) {
    this.dynamicEnts = dynamicEnts;
    this.staticGrid = staticGrid;
    this.map = map;
    this.time = time;
  }
  
  
  void update() {
    uint elapsed = time.delta;
    time.delta = 1;
    foreach (ent; dynamicEnts) {
      for (int i = 0; i < elapsed; i++) {
          ent.clearNearby();
          ent.tickUpdate();
      }
      
      if (ent.update !is null) {
        if (ent.update.timeDelta > time.delta)
            time.delta = ent.update.timeDelta;
      
        bool statsMet;
        bool keep = ent.update.run(elapsed, statsMet);
        
        if (!keep) {
            if (statsMet)
                ent.update = ent.update.next();
            else
                ent.update = null;
        }
      }
    }
    
    time.increment();
  }
  
  
  /// All of the Ents, both static and dynamic, at the given Coord
  Ent[] entsAt(Coord coord) {
    Ent[] ents;
    
    ents = staticGrid.at(coord).ents.dup;
    
    foreach (ent; dynamicEnts) {
      if (ent.coord == coord) {
        ents ~= ent;
      }
    }
    
    return ents;
  }
  
  
  /// Returns the dynamic Ents within 'radius' units of the given center
  DynamicEnt[] dynamicEntsInRadius(int radius, Coord center) {
    DynamicEnt[] ents;
    
    foreach (ent; dynamicEnts) {
      auto diff = ent.coord - center;
    
      if (math.abs(diff.x) <= radius && 
          math.abs(diff.y) <= radius) {
        ents ~= ent;
      }
    }
    
    return ents;
  }
  
  DynamicEntDistance[] dynamicEntsInRadiusDistances(int radius, Coord center) {
    return dynamicEntsInRadiusDistances(radius, center, dynamicEntsInRadius(radius, center));
  }
  
  /// Returns the dynamic Ents within 'radius' units of the given center, 
  /// along with their direct distance from the center, sorted, 
  /// closest to farthest
  ///
  /// Returns: a struct that is aliased to the Ent, but that also
  ///          includes int distance
  DynamicEntDistance[] dynamicEntsInRadiusDistances(int radius, Coord center, DynamicEnt[] ents) {
    DynamicEntDistance[] entsDistances = new DynamicEntDistance[](ents.length);
    
    foreach (i, ent; ents) {
      entsDistances[i] = 
        DynamicEntDistance(ent, distanceBetween(ent.coord, center));
    }
    
    alg.sort!("a.distance < b.distance")(entsDistances);
    
    return entsDistances;
  }
  
  
  /// Get all of the static Ents within 'radius' units of the given center
  Ent[] staticEntsInRadius(int radius, Coord center) {
    Ent[] ents;
    
    for (int xd = -radius; xd <= radius; ++xd) {
      for (int yd = -radius; yd <= radius; ++yd) {
        ents ~= staticGrid.at(center + Coord(xd, yd)).ents;
      }
    }
    
    return ents;
  }
  
  
  /// Get *all* Ents within 'radius' units of the given center
  ///
  /// This includes dynamic Ents, static Ents, and Ents that are within
  /// the Terrain
  Ent[] allEntsInRadius(int radius, Coord center) {
    Ent[] ents = cast(Ent[]) dynamicEntsInRadius(radius, center);
    
    for (int xd = -radius; xd <= radius; ++xd) {
      for (int yd = -radius; yd <= radius; ++yd) {
        auto stat = staticGrid.at(center + Coord(xd, yd));
        
        ents ~= stat.ents;
        
        if (stat.terrain.ent !is null) {
          ents ~= stat.terrain.ent;
        }
      }
    }
    
    return ents;
  }
  
  
  static struct StaticContents {
    Terrain terrain;
    Ent[] ents;
    Tracks tracks;
  }
  
  
  static struct MapContents {
    Geo geo;
    bool isDiscovered;
  }
  
  
  Coord mapCoord(Coord coord) const {
    float x = coord.x,
          y = coord.y;
          
    return Coord(cast(int) math.floor(x * map.width / 
                                      staticGrid.width), 
                 cast(int) math.floor(y * map.height / 
                                      staticGrid.height));
  }
  
  
  /// Returns true if the given Coord is visible to the player
  bool isInView(Coord coord) {
    auto diff = coord - player.coord;
    
    return math.abs(diff.x) <= player.viewRadius &&
           math.abs(diff.y) <= player.viewRadius;
  }
  
  
  /// Checks if there is anything blocking movement at the given coord
  bool isBlockingAt(Coord coord) {
    if (!staticGrid.isInside(coord)) return true;
    
    auto stat = staticGrid.at(coord);
    
    if (stat.terrain.isBlocking) {
      return true;
    } else {
      foreach (ent; stat.ents) {
        if (ent.tags.isBlocking) {
          return true;
        }
      }
    }
    
    foreach (ent; world.dynamicEnts) {
      if (ent.coord == coord && ent.tags.isBlocking) {
        return true;
      }
    }
    
    return false;
  }
  
  bool isAirBlockingAt(Coord coord) {
    if (!staticGrid.isInside(coord)) return true;
    
    auto stat = staticGrid.at(coord);
    
    if (stat.terrain.isAirBlocking) {
      return true;
    } else {
      foreach (ent; stat.ents) {
        if (ent.tags.isAirBlocking) {
          return true;
        }
      }
    }
    
    foreach (ent; world.dynamicEnts) {
      if (ent.coord == coord && ent.tags.isAirBlocking) {
        return true;
      }
    }
    
    return false;
  }
  
  
  /// Calculates the movement cost at the given coord
  int movementCostAt(Coord coord) {
    int cost;
  
    auto ents = entsAt(coord);
    auto terrain = staticGrid.at(coord).terrain;
    
    foreach (ent; ents) {
      cost += ent.tags.movementCost;
    }
    
    cost += terrain.movementCost;
    
    return cost;
  }
  
  
  /// Add the given Ent to the world
  void add(Ent ent) {
    /// Find out if it's a DynamicEnt so we know where to add it
    auto dynamic = cast(DynamicEnt) ent;
    
    if (dynamic !is null) {
      dynamicEnts ~= dynamic;
    } else {
      staticGrid.at(ent.coord).ents ~= ent;
    }
  }
  
  
  /// Remove the given ent from the world
  void remove(Ent ent) {
    /// Find out if it's a DynamicEnt so we know where to remove it from
    auto dynamic = cast(DynamicEnt) ent;
    
    if (dynamic !is null) {
      dynamicEnts.remove(dynamic);
    } else {
      staticGrid.at(ent.coord).ents.remove(ent);
    }
  }
}


/// The footprint tracks left by a walking Ent
///
/// If ent is null, there are no tracks here.
struct Tracks {
  private Ent _ent;
  int timeMade;
  int relativeAge;
  
  /// The maximum age a track can reach before it disappears
  immutable int maxAge = Time.fromHours(6);
  
  static immutable Sym sym = Sym('"', Color.YellowBBg);
  
  int age() const {
    return world.time.ticks - timeMade;
  }
  
  
  /// Updates the Track before return a reference to ent
  ///
  /// Checks if the track has surpassed the maximum age, and if so
  /// sets ent to null
  @property ref Ent ent() {
    if (_ent !is null) {
      if (age > maxAge) {
        _ent = null;
      }
    }
  
    return _ent;
  }
}


/// Keeps track of in-game time and offers some utility functions
struct Time {
  uint ticks;    /// How many ticks have elapsed in the game
  uint delta = 1;  /// How many ticks to increment each frame (increase to speed up game)
       
  private immutable int ticksPerSecond = 100, /// How many ticks in a single second
                        dawnDuskTicks = fromMinutes(12); /// How long dawn/dusk last
  private immutable float moonSpeed = .01,  /// How much the moon moves per period
                          moonOffset = .4; /// Where the moon starts 
       
  /// Moves time forward, defaulting to a single tick
  void increment() {
    ticks += delta;
  }
  
  
  /// How many periods have elapsed in the game
  int periods() const {
    return ticks / fromPeriods(1);
  }
  
  
  /// How many ticks have passed in the current period
  int periodTicks() const {
    return ticks % fromPeriods(1);
  }
  
  
  /// If it is currently daytime
  bool isDay() const {
    return (periods % 2) == 0;
  }
  
  
  /// If it is currently dawn
  bool isDawn() const {
    return isDay && periodTicks <= dawnDuskTicks;
  }
  
  
  /// If it is currently dusk
  bool isDusk() const {
    return isDay && (fromPeriods(1) - periodTicks) <= dawnDuskTicks;
  }
  
  
  /// The sun's position in the sky
  ///
  /// Return: the sun's position between 0.0 and 1.0
  float sunPosition() const {
    return periodTicks / fromPeriods(1);
  }
  
  
  /// The moon's position in the sky
  ///
  /// Return: the moon's position between 0.0 and 1.0
  float moonPosition() const {
    return (periods * moonSpeed + moonOffset) % 1;
  }
  
  
  /// Converts into ticks
  static int fromSeconds(int secs) {
    return secs * ticksPerSecond;
  }
  
  static int fromSeconds(float secs) {
    return cast(int)(secs * ticksPerSecond);
  }
  
  /// ditto
  static int fromMinutes(int mins) {
    return fromSeconds(mins * 60);
  }
  
  static int fromMinutes(float mins) {
    return fromSeconds(mins * 60);
  }
  
  /// ditto
  static int fromHours(int hrs) {
    return fromMinutes(hrs * 60);
  }
  
  /// ditto
  static int fromHours(float hrs) {
    return fromMinutes(hrs * 60);
  }
  
  /// ditto
  static int fromPeriods(int pers) {
    return fromHours(pers * 12);
  }
  
  /// ditto
  static int fromPeriods(float pers) {
    return fromHours(pers * 12);
  }
}

abstract class Sound {
    static enum Mood {
        Friendly,
        Neutral,
        Aggressive
    }
    
    string desc;
    Mood mood;
    int radius;
    Ent ent;
    Coord coord;
    
    this(string desc, Mood mood, int radius, Ent ent) {
        this.desc = desc;
        this.mood = mood;
        this.radius = radius;
        this.ent = ent;
        coord = ent.coord;
    }
    
    string message() {
        return format("You hear %s from the %s.", desc, directionName(directionBetween(player.coord, coord)));
    }
    
    void broadcast() {
        foreach (DynamicEnt ent; world.dynamicEnts) {
            if (ent !is this.ent) {
                if (distanceBetween(coord, ent.coord) <= radius) {
                    ent.hearSound(this);
                }
            }
        }
    }
}

struct DynamicEntDistance {
  DynamicEnt _ent;
  int distance;

  alias _ent this;
}
