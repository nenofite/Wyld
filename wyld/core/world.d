/// Contains the data structure of the in-game world
module wyld.core.world;

import wyld.core.common;
import wyld.core.ent;
import wyld.ent;
import wyld.main;

import alg = std.algorithm;
import math = std.math;

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
    foreach (ent; dynamicEnts) {
      ent.tickUpdate();
      
      if (ent.update !is null) {
        auto keep = ent.update.run();
        
        if (!keep) {
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
  
  
  /// The Ents within nearbyRadius of the given StatEnt
  Ent[] nearbyEnts(StatEnt statEnt) {
    Ent[] ents;
  
    foreach (ent; dynamicEnts) {
      if (ent.coord.x >= statEnt.coord.x - statEnt.nearbyRadius &&
          ent.coord.x <= statEnt.coord.x + statEnt.nearbyRadius &&
          ent.coord.y >= statEnt.coord.y - statEnt.nearbyRadius &&
          ent.coord.y <= statEnt.coord.y + statEnt.nearbyRadius) {
        if (ent !is statEnt) {
          ents ~= ent;
        }
      }
    }
    
    return ents;
  }
  
  /// The Ents within nearbyRadius of the given StatEnt, along with their
  /// direct distance from that Coord and sorted, closest to farthest
  ///
  /// Return: a struct that is aliased to the Ent, but that also includes
  ///         int distance
  auto nearbyEntsDistances(StatEnt statEnt) {
    struct EntDistance {
      Ent _ent;
      int distance;
      
      alias _ent this;
    }
    
    auto ents = nearbyEnts(statEnt);
    EntDistance[] entsDistances = new EntDistance[](ents.length);
    
    foreach (i, ent; ents) {
      entsDistances[i] = 
        EntDistance(ent, distanceBetween(ent.coord, statEnt.coord));
    }
    
    alg.sort!("a.distance < b.distance")(entsDistances);
    
    return entsDistances;
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
  int ticks;    /// How many ticks have elapsed in the game
       
  private immutable int ticksPerSecond = 100, /// How many ticks in a single second
                        dawnDuskTicks = fromMinutes(12); /// How long dawn/dusk last
  private immutable float moonSpeed = .01,  /// How much the moon moves per period
                          moonOffset = .4; /// Where the moon starts 
       
  /// Moves time forward, defaulting to a single tick
  void increment(int newTicks = 1) {
    ticks += newTicks;
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
  
  /// ditto
  static int fromMinutes(int mins) {
    return fromSeconds(mins * 60);
  }
  
  /// ditto
  static int fromHours(int hrs) {
    return fromMinutes(hrs * 60);
  }
  
  /// ditto
  static int fromPeriods(int pers) {
    return fromHours(pers * 12);
  }
}