/// Contains the data structure of the in-game world
module wyld.core.world;

import wyld.core.common;
import wyld.core.ent;

/// The current game world, available for easy access
World world;


/// Contains the terrain, ents, map, time, etc. of the in-game world
class World : Ent.Location {
  DynamicEnt[] dynamicEnts; /// The Ents that need updating
  StaticGrid staticGrid;    /// A grid of static terrain, ents, and tracks
  Map map;    /// The map of the world, used for map screen and minimap
  Time time;  /// The in-game time
  
  /// Add the given Ent to the World
  ///
  /// Return: the Ent location Link for the Ent to use
  Ent.Link add(Ent ent, Coord coord) {
    return new Link(ent, coord, ((cast(DynamicEnt) ent) is null));
  }
  
  
  /// All of the Ents, both static and dynamic, at the given Coord
  Ent[] entsAt(Coord coord) {
    Ent[] ents;
    
    ents = at(coord).ents.dup;
    
    foreach (ent; dynamicEnts) {
      if (ent.coord == coord) {
        ents ~= ent;
      }
    }
    
    return ents;
  }
  
  
  /// The Ents within nearbyRadius of the given Coord
  Ent[] nearbyEntsAt(Coord coord) {
    Ent[] ents;
  
    foreach (ent; dynamicEnts) {
      if (ent.coord.x >= coord.x - nearbyRadius &&
          ent.coord.x <= coord.x + nearbyRadius &&
          ent.coord.y >= coord.y - nearbyRadius &&
          ent.coord.y <= coord.y + nearbyRadius) {
        ents ~= ent;
      }
    }
    
    return ents;
  }
  
  /// The Ents within nearbyRadius of the given Coord, along with their
  /// direct distance from that Coord and sorted, closest to farthest
  ///
  /// Return: a struct that is aliased to the Ent, but that also includes
  ///         int distance
  auto nearbyEntsDistancesAt(Coord coord) {
    struct EntDistance {
      Ent _ent;
      int distance;
      
      alias _ent this;
    }
    
    auto ents = nearbyEntsAt(coord);
    EntDistance[] entsDistances = new EntDistance[](ents.length);
    
    foreach (i, ent; ents) {
      entsDistances[i] = 
        EntDistance(ent, distanceBetween(ent.coord, coord));
    }
    
    entsDistances.sort!("a.distance < b.distance")();
    
    return entsDistances;
  }
  
  
  /// A grid of static terrain, ents, and tracks
  static class StaticGrid : Grid!(StaticGridContents) {
    this(int width, int height) {
      super(width, height);
    }
  }
  
  static struct StaticGridContents {
    Terrain terrain;
    Ent[] ents;
    Tracks tracks;
  }
  
  
  /// The map of the world, used for map screen and minimap
  static class Map : Grid!(MapContents) {
    this(int width, int height) {
      super(width, height);
    }
  }
  
  static struct MapContents {
    Geo geo;
    bool isDiscovered;
  }
  
  
  
  
  /// World's Ent location Link, including info on whether the Ent is
  /// static or dynamic and what its Coords are
  static class Link : Ent.Link {
    Coord coord;
    bool isStatic;
    
    this(Ent ent, Coord coord, bool isStatic) {
      super(ent);
      this.coord = coord;
      this.isStatic = isStatic;
    }
    
    
    void remove() {
      if (isStatic) {
        world.staticGrid.at(coord).ents.remove(ent);
      } else {
        world.dynamicEnts.remove(ent);
      }
    }
  }
}


/// The footprint tracks left by a walking Ent
struct Tracks {
  Ent ent;
  int timeMade;
  int relativeAge;
  
  int age() const {
    return world.time.ticks - timeMade;
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
