/// Contains things directly concerning the Ent system
module wyld.core.ent;

import wyld.core.common;
import wyld.core.world;
import wyld.main;


/// Represents an object within the game that is interactive
abstract class Ent {
  string name;  /// Human-readable in-game name of this Ent
  Sym sym;  /// Graphical representation of the Ent
  Tags tags;  /// Tags describing this Ent's characteristics
  Link location; /// This ent's current Location, or null if inside World itself
  Coord coord; /// Coord inside of World, if this Ent is inside of World
  int movementCost; /// How long it takes other Ents to move by this Ent
  /// If the Ent blocks movement entirely
  bool isBlocking;
  
  /// Remove this Ent from current parent, attempt to add to new one
  void relocate(Location newLocation) {
    if (location !is null) {
      location.remove();
    } else {
      world.remove(this);
    }
    
    if (newLocation !is null) {
      location = newLocation.add(this);
    } else {
      location = null;
    }
  }
  
  
  /// If this Ent is currently inside a location
  ///
  /// Return: true if its inside a location, false if it is just inside World
  bool isInside() {
    return (location !is null);
  }
  
  
  /// Tags contain various Ent characteristics used for interactivity
  static struct Tags {
    int weight; /// Weight of this Ent in pounds
    int size; /// Size of this Ent in cubic inches
    bool isFluid; /// If this Ent is fluid
    //TODO finish transferring tags
  }
  
  
  /// Represents something that can contain Ents
  static interface Location {
    /// How much room there is for more Ents
    ///
    /// Return: the available space in cubic inches or -1 if infinite
    ///         room is available
    int availableRoom();
    
    /// If this Location can hold fluid Ents
    bool isWatertight();
    
    /// Try to add an Ent
    Link add(Ent);
    
  }
  
  
  /// Describes an Ent's membership inside this Location
  ///
  /// Links are used to track membership and remove the Ent from
  /// the Location when the time comes
  static abstract class Link {
    Ent ent;
    
    this(Ent ent) {
      this.ent = ent;
    }
    
    
    /// Remove the Ent from the linked Location
    void remove();
  }
}


/// An Ent that constantly updates in the world
abstract class DynamicEnt : Ent {
  Update update;  /// The Ent's currently running update
  /// How long it takes the Ent to move one space, not including
  /// the movement cost of the surroundings
  int speed;
  
  /// Called once every tick to update simple things such as Stats
  void tickUpdate() {}
  
  
  void move(Coord deltaCoord) {
    static class Upd : Update {
      Coord newCoord;
      DynamicEnt ent;
    
      this(Coord newCoord, DynamicEnt ent) {
        this.newCoord = newCoord;
        this.ent = ent;
        
        auto time = world.movementCostAt(newCoord) + 
                    world.movementCostAt(ent.coord) + 
                    ent.speed - 
                    ent.movementCost;
        super(time, [], []);
      }
      
      
      void apply() {
        ent.coord = newCoord;
      }
    }
    
    assert(!isInside);
    auto newCoord = coord + deltaCoord;
  
    
    if (world.isBlockingAt(newCoord)) {
    } else {
      update = new Upd(newCoord, this);
    }
  }
}


/// An action performed by an Ent, involving time and Stat requirements
abstract class Update {
  int consumeTime;  /// The amount of ticks needed to perform this
  StatRequirement[] requireStats, /// Stats that must be at a certain amount
                    consumeStats; /// Stats that will be used up by this
             
  this(int consumeTime, 
       StatRequirement[] requireStats, 
       StatRequirement[] consumeStats) {
    this.consumeTime = consumeTime;
    this.requireStats = requireStats;
    this.consumeStats = consumeStats;
  }
  
  
  /// The actual action, ran once the stats are met and the time has passed
  protected void apply();
  
  
  /// Update this Update by one tick, and run it if the time has come
  /// Return: false once the command has ran/the required stats weren't met
  bool run() {
    foreach (stat; requireStats ~ consumeStats) {
      if (!stat.check) return false;
    }
  
    if (consumeTime > 0) {
      --consumeTime;
      return true;
    } else {
      foreach (stat; consumeStats) {
        assert(stat.check);
        stat.consume();
      }
      
      apply();
      return false;
    }
  }
}


/// A Stat for an Ent, containing a current value and a maximum value
struct Stat {
  private int _amount;
  int max;
  
  alias amount this;
  
  this(int amount, int max) {
    _amount = amount;
    this.max = max;
  }
  
  this(int max) {
    this(max, max);
  }
  
  
  @property ref int amount() {
    /// Clip _amount to 0 <= _amount <= max
    if (_amount < 0) {
      _amount = 0;
    } else if (_amount > max) {
      _amount = max;
    }
    
    return _amount;
  }
  
  
  /// Draw a bar representing this stat's value
  void drawBar(int width = 10) {
    /// Calculate how much of the bar is filled in
    int filledWidth = cast(int) 
      math.ceil(cast(float) amount / max * width);
    
    /// Draw the filled in part
    setColor(Color.Green);
    for (int i = 0; i < filledWidth; ++i) {
      ncs.addch('=');
    }
    
    /// Draw the rest
    setColor(Color.Red);
    for (int i = 0; i < width - filledWidth; ++i) {
      ncs.addch('-');
    }
  }
}


/// A requirement for a certain Stat, for use in Update
struct StatRequirement {
  /// The Stat in question
  Stat* stat;
  /// The amount required/consumed
  int amount;
  
  /// Check if the requirement is met
  /// Return: true if it is met
  bool check() {
    return stat.amount >= amount;
  }
  
  
  /// Consume the amount specified from the Stat
  void consume() {
    stat.amount -= amount;
  }
}