/// Contains the data structure of the in-game world
module wyld.world;

import wyld.common;
import wyld.ent;


/// Contains the terrain, ents, map, time, etc. of the in-game world
class World {
  DynamicEnt[] dynamicEnts; /// The Ents that need updating
  StaticGrid staticGrid;    /// A grid of static terrain, ents, and tracks
  Map map;    /// The map of the world, used for map screen and minimap
  Time time;  /// The in-game time
  
  /// The current game world, available for easy access
  static World world;
  
  
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
  
  
  /// Keeps track of in-game time and offers some utility functions
  static struct Time {
    int ticks;    /// How many ticks have elapsed in the game
         
    private immutable int ticksPerSecond = 100, /// How many ticks in a single second
                          moonSpeed = 1,  /// How many periods before the moon moves
                          moonOffset = sunMoonResolution / 3, /// Where the moon starts
                          /// How many intervals along the sky the sun and moon will travel by
                          sunMoonResolution = 200,  
                          dawnDuskTicks = fromMinutes(12); /// How long dawn/dusk last
         
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
    int sunPosition() const {
      return periodTicks / fromPeriods(1) * sunMoonResolution;
    }
    
    
    /// The moon's position in the sky
    int moonPosition() const {
      return (periods * moonSpeed + moonOffset) % sunMoonResolution;
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
}


struct Tracks {
  Ent ent;
  int timeMade;
  int relativeAge;
  
  int age() const {
    return World.world.time.ticks - timeMade;
  }
}