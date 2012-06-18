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
       
  this(string name, 
       Sym sym, 
       Tags tags, 
       Link location, 
       Coord coord, 
       Stat hp, 
       Stat sp, 
       Stat thirst, 
       Stat hunger, 
       int viewRadius, 
       int nearbyRadius) {
    super(name, sym, tags, location, coord);
    
    this.hp = hp;
    this.sp = sp;
    this.thirst = thirst;
    this.hunger = hunger;
    this.viewRadius = viewRadius;
    this.nearbyRadius = nearbyRadius;
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
  this(Coord coord) {
    Tags tags;
    
    tags.size = 6000;
    
    tags.isBlocking = true;
    tags.speed = 50;
  
    super("you", Sym('@', Color.Blue), tags, null, coord, 
          Stat(500), Stat(500), Stat(400), Stat(200), 12, 25);
  }
}


class Deer : StatEnt {
  this(Coord coord) {
    Tags tags;
    
    tags.size = 6000;
    
    tags.isBlocking = true;
    tags.speed = 50;
  
    super("deer", Sym('D', Color.White), tags, null, coord,
          Stat(300), Stat(500), Stat(400), Stat(200), 6, 18);
  }
  
  
  void tickUpdate() {
    StatEnt.tickUpdate();
    
    if (update is null) {
    }
  }
}


class Grass : Ent {
  this(Coord coord) {
    Tags tags;
    
    tags.size = 8;
    
    tags.movementCost = 20;
  
    super("grass", Sym('"', Color.Green), tags, null, coord);
  }
}


class Tree : Ent {
  this(Coord coord) {
    Tags tags;
    
    tags.size = 24000;
    
    tags.isBlocking = true;
    
    auto color = rand.uniform(0, 10) == 0 ? Color.Yellow : Color.Green;
    
    super("tree", Sym('7', color), tags, null, coord);
  }
}