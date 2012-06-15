/// Contains things directly concerning the Ent system
module wyld.core.ent;

import wyld.core.common;


/// Represents an object within the game that is interactive
abstract class Ent {
  Link location; /// This ent's current Location
  Tags tags;  /// Tags describing this Ent's characteristics
  
  /// Remove this Ent from current parent, attempt to add to new one
  void relocate(Location newLocation) {
    if (location !is null) {
      location.remove();
    }
    
    location = newLocation.add(this);
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
    
    /// Remove the Ent from the linked Location
    void remove();
  }
}


/// An Ent that constantly updates in the world
abstract class DynamicEnt : Ent {
  Update update;  /// The Ent's currently running update
}


/// An action performed by an Ent, involving time and Stat requirements
abstract class Update {
  private int consumeTime;  /// The amount of ticks needed to perform this
  private StatRequirement[] requireStats, /// Stats that must be at a certain amount
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
  int amount, max;
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