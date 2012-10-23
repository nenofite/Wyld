/// Contains things directly concerning the Ent system
module wyld.core.ent;

import wyld.core.common;
import wyld.core.menu;
import wyld.core.world;
import wyld.ent;
import wyld.main;


/// Represents an object within the game that is interactive
abstract class Ent {
  /// Human-readable in-game name of this Ent
  string name;  
  /// Graphical representation of the Ent
  Sym sym;  
  /// Tags describing this Ent's characteristics
  Tags tags;  
  /// The container Ent this Ent is inside, or null if its directly
  /// in World
  Ent container; 
  /// The Ents that are contained by/inside of this Ent
  Ent[] contained;
  /// Coord inside of World, if this Ent is inside of World
  Coord coord;
  
  this(string name, 
       Sym sym, 
       Tags tags,
       Coord coord) {
    this.name = name;
    this.sym = sym;
    this.tags = tags;
    this.coord = coord;
  }
  
  /// Remove this Ent from current container, attempt to add to new one
  void relocate(Ent newContainer) {
    if (container !is null) {
      container.contained.remove(this);
    } else {
      world.remove(this);
    }
    
//    assert(newContainer.freeSpace >= tags.size);
    
    addTo(newContainer);
  }
  
  
  void addTo(Ent newContainer) {
    container = newContainer;
    if (newContainer !is null) {
      container.contained ~= this;
    } else {
      world.add(this);
    }
  }
  
  
  /// Returns the amount of unused space left in this container
  int freeSpace() {
    /// Start by summing up the total space being used by current residents
    int usedSpace;
    
    foreach (ent; contained) {
      usedSpace += ent.tags.size;
    }
    
    /// Subtract that from the total space this can hold
    return cast(int) (tags.size * tags.containCo - usedSpace);
  }
  
  
  /// Tags contain various Ent characteristics used for interactivity
  ///
  /// All contained coefficient values (their names end in 'Co') are multiplied
  /// by 'size' for their final amount
  static struct Tags {
    /// Size of this Ent in cubic inches
    int size; 
    /// Weight of this Ent in pounds
    int weight; 
    /// If this Ent is fluid
    bool isFluid; 
    
    /// If this Ent blocks others' movement entirely
    bool isBlocking, isAirBlocking; 
    /// The coefficient for how much of the Thirst stat this replenishes
    /// upon drinking
    float drinkCo = 0;
    /// The coefficient for how much space their is available inside
    /// this Ent to contain other Ents
    float containCo = 0;
    /// How long it takes other Ents to move by this Ent
    int movementCost; 
    /// How long it takes the Ent to move one space, not including
    /// the movement cost of the surroundings
    int speed;
    
    bool stick, bigStick, sharp, bigSharp, tie;
    
    int damage, accuracy;
    Attack.Type damageType;
    
    // TODO finish transferring tags
  }
}


/// An Ent that constantly updates in the world
abstract class DynamicEnt : Ent {
  Update update;  /// The Ent's currently running update
  
  /// The radius of the view around the Ent
  ///
  /// This technically isn't the radius, because it doesn't count the
  /// Ent's own square.  This is actually one less than the radius.
  int viewRadius; 

  /// The radius where the Ent can make out other dynamic Ents
  ///
  /// Same as viewRadius as far as technicalities
  int nearbyRadius;
  
  private DynamicEnt[] _nearbyEnts;
  private bool _nearbyEntsCached;
  private DynamicEntDistance[] _nearbyEntsDistances;
  private bool _nearbyEntsDistancesCached;
  private Ent[] _entsOnGround;
  private bool _entsOnGroundCached;
  
  this(string name, 
       Sym sym, 
       Tags tags, 
       Coord coord,
       int viewRadius,
       int nearbyRadius) {
    super(name, sym, tags, coord);
    
    this.viewRadius = viewRadius;
    this.nearbyRadius = nearbyRadius;
  }
  
  DynamicEnt[] nearbyEnts() {
    if (!_nearbyEntsCached) {
        _nearbyEnts = world.dynamicEntsInRadius(nearbyRadius, coord);
        _nearbyEnts.remove(this);
        _nearbyEntsCached = true;
    }
    
    return _nearbyEnts;
  }
  
  DynamicEntDistance[] nearbyEntsDistances() {
    if (!_nearbyEntsDistancesCached) {
        _nearbyEntsDistances = world.dynamicEntsInRadiusDistances(nearbyRadius, coord, nearbyEnts());
        _nearbyEntsDistancesCached = true;
    }
    
    return _nearbyEntsDistances;
  }
  
  Ent[] entsOnGround() {
    if (!_entsOnGroundCached) {
        _entsOnGround = world.allEntsInRadius(1, coord);
        _entsOnGround.remove(this);
        _entsOnGroundCached = true;
    }
    
    return _entsOnGround;
  }
  
  void clearNearby() {
    _nearbyEnts = null;
    _nearbyEntsCached = false;
    _entsOnGround = null;
    _entsOnGroundCached = false;
  }
  
  /// Called once every tick to update simple things such as Stats
  void tickUpdate() {}
  
  abstract void hearSound(Sound);
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
  
  Update next() {
    return null;
  }
  
  /// Update this Update by one tick, and run it if the time has come
  /// Return: false once the command has ran/the required stats weren't met
  bool run(out bool statsMet) {
    foreach (stat; requireStats)
        if (!stat.check()) {
            menu.addMessage(stat.failMessage);
            statsMet = false;
            return false;
        }
    
    foreach (stat; consumeStats)
        if (!stat.check()) {
            menu.addMessage(stat.failMessage);
            statsMet = false;
            return false;
        }
  
    statsMet = true;
  
    if (consumeTime > 0) {
      --consumeTime;
      return true;
    } else {
      foreach (stat; consumeStats) {
        assert(stat.check());
        stat.consume();
      }
      
      apply();
      return false;
    }
  }
}


class MoveUpdate : Update {
    DynamicEnt ent;
    Coord dest;
    
    this(DynamicEnt ent, Coord delta) {
        this.ent = ent;
        this.dest = ent.coord + delta;
        
        auto time = world.movementCostAt(dest) + 
                    world.movementCostAt(ent.coord) + 
                    ent.tags.speed - 
                    ent.tags.movementCost;

        super(time, [], []);
    }
    
    static MoveUpdate withCheck(DynamicEnt ent, Coord delta) {
        auto coord = ent.coord + delta;
        
        if (world.isBlockingAt(coord)) {
            return null;
        }
        
        return new MoveUpdate(ent, delta);
    }
    
    void apply() {
        if (!world.isBlockingAt(dest)) {
            ent.coord = dest;
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
  
  string failMessage;
  
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


/// Represents something that can be done with an Ent
///
/// For example, eating an edible piece of food, or stacking together
/// items of the same type
///
/// Classes shouldn't directly extend this class, but instead one of its
/// children classes: Interaction.Single or Interaction.Multiple.
abstract class Interaction {
  char key;
  string title;

  this(char key, string title) {
    this.key = key;
    this.title = title;
  }
  
  
  /// Returns true if the given Ent is one that this Interaction works on
  bool isApplicable(Ent);
  
  
  /// Represents an Interaction that only applies to a single object at a
  /// time, as opposed to applying to a group of objects taken together
  ///
  /// For example, eating a piece of food or placing an item into a pack
  static abstract class Single : Interaction {
    this(char key, string title) {
      super(key, title);
    }
    
    
    /// Apply this Interaction's effect to the given Ent
    ///
    /// The given Ent is guaranteed to have already passed this Interaction's
    /// isApplicable().
    void apply(Ent);
  }
  
  
  /// Represents an Interaction that applies to a group of objects taken together
  ///
  /// For example, stacking together multiple items, or mixing together
  /// two fluids
  static abstract class Multi : Interaction {
    this(char key, string title) {
      super(key, title);
    }
    
    
    /// Apply this Interaction's effect to the given group of Ents
    ///
    /// All the given Ents are guaranteed to have already passed this Interaction's
    /// isApplicable() individually, as well as together in this Ent's
    /// isMultiApplicable().
    void apply(Ent[]);
    
    /// Returns true if the given Ents would work together in a group for
    /// this Interaction
    ///
    /// All Ents in the given array are guaranteed to have already passed 
    /// this Interaction's isApplicable() before making it into the list.
    bool isMultiApplicable(Ent[]);
  }
}
