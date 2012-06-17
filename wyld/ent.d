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
  
  
  void tickUpdate() {
    /// Every minute
    if (world.time.ticks % Time.fromMinutes(1) == 0) {
      --thirst;
      ++sp;
    }
    /// Every ten minutes
    if (world.time.ticks % Time.fromMinutes(10) == 0) {
      --hunger;
    }
  }
  
  
  void move(Coord deltaCoord) {
    DynamicEnt.move(deltaCoord);
    
    if (update !is null) {
      update.consumeStats ~= StatRequirement(&sp, update.consumeTime);
    }
  }
}


class Player : StatEnt {
  this() {
    super(Stat(500), Stat(200), Stat(400), Stat(200), 12);
  }
}