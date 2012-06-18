/// This contains the game-specific, concrete Ents
module wyld.ent;

import wyld.core.common;
import wyld.core.ent;
import wyld.core.world;


/// An Ent with basic Stats
abstract class StatEnt : DynamicEnt {
  Stat hp,
       sp,
       thirst,
       hunger;
       
  /// The radius of the view around the Ent
  ///
  /// This technically isn't the radius, because it doesn't count the
  /// Ent's own square.  This is actually one less than the radius.
  int viewRadius;
  /// The radius where the Ent can make out other dynamic Ents
  ///
  /// Same as viewRadius as far as technicalities
  int nearbyRadius;
       
  this(Stat hp, Stat sp, Stat thirst, Stat hunger, int viewRadius) {
    this.hp = hp;
    this.sp = sp;
    this.thirst = thirst;
    this.hunger = hunger;
    this.viewRadius = viewRadius;
  }
  
  
  /// Regenerate (and degrade) certain stats over time
  void tickUpdate() {
    if (world.time.ticks % Time.fromSeconds(1) == 0) {
      ++sp;
    }
    
    if (world.time.ticks % Time.fromMinutes(1) == 0) {
      --thirst;
    }
    
    if (world.time.ticks % Time.fromMinutes(10) == 0) {
      --hunger;
    }
  }
  
  
  void move(Coord deltaCoord) {
    DynamicEnt.move(deltaCoord);
    
    if (update !is null) {
      update.consumeStats ~= StatRequirement(&sp, 1);
    }
  }
}


class Player : StatEnt {
  this() {
    super(Stat(500), Stat(500), Stat(400), Stat(200), 12);
    
    name = "you";
    sym = Sym('@', Color.Blue);
  }
}


class Grass : Ent {
  this(Coord coord) {
    this.coord = coord; // TODO put this in Ent's constructor
  
    name = "grass";
    sym = Sym('"', Color.Green);
  }
}


class Tree : Ent {
  this(Coord coord) {
    this.coord = coord;
    
    name = "tree";
    
    auto color = rand.uniform(0, 10) == 0 ? Color.Yellow : Color.Green;
    sym = Sym('t', color);
    
    isBlocking = true;
  }
}