/// This contains the game-specific, concrete Ents
module wyld.ent;

import wyld.core.common;
import wyld.core.ent;
import wyld.core.world;
import wyld.interactions;


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
       Coord coord, 
       Stat hp, 
       Stat sp, 
       Stat thirst, 
       Stat hunger, 
       int viewRadius, 
       int nearbyRadius) {
    super(name, sym, tags, coord);
    
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
  Interaction[] interactions;

  this(Coord coord) {
    Tags tags;
    
    tags.size = 6000;
    
    tags.isBlocking = true;
    
    tags.containCo = .05;
    
    tags.speed = 50;
  
    super("you", Sym('@', Color.Blue), tags, coord, 
          Stat(500), Stat(500), Stat(400), Stat(200), 12, 25);
          
    interactions = [
      new PickUp(),
      cast(Interaction) new Drink()
    ];
  }
}


class Deer : StatEnt {
  Coord dest;
  bool hasDest;

  this(Coord coord) {
    Tags tags;
    
    tags.size = 6000;
    
    tags.isBlocking = true;
    tags.speed = 50;
  
    super("deer", Sym('D', Color.White), tags, coord,
          Stat(300), Stat(500), Stat(400), Stat(200), 6, 18);
  }
  
  
  void tickUpdate() {
    StatEnt.tickUpdate();
    
    if (update is null) {
      if (coord == dest) {
        hasDest = false;
      }
    
      if (hasDest) {
        move(coordFromDirection(directionBetween(coord, dest)));
        
        if (update is null) {
          hasDest = false;
        }
      } else {
        dest.x = rand.uniform(0, world.staticGrid.width);
        dest.y = rand.uniform(0, world.staticGrid.height);
        
        if (!world.isBlockingAt(dest)) {
          hasDest = true;
        }
      }
    }
  }
}


class Grass : Ent {
  this(Coord coord) {
    Tags tags;
    
    tags.size = 8;
    
    tags.movementCost = 20;
  
    super("grass", Sym('"', Color.Green), tags, coord);
  }
}


class Tree : Ent {
  this(Coord coord) {
    Tags tags;
    
    tags.size = 24000;
    
    tags.isBlocking = true;
    
    auto color = rand.uniform(0, 10) == 0 ? Color.Yellow : Color.Green;
    
    super("tree", Sym('7', color), tags, coord);
  }
}


class Water : Ent {
  this(int size, Coord coord = Coord(-1, -1)) {
    Tags tags;
    
    tags.size = size;
    
    tags.isFluid = true;
    
    tags.drinkCo = 1;
    
    super("water", Sym('~', Color.Blue), tags, coord);
  }
}