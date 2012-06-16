/// This contains the game-specific, concrete Ents
module wyld.ent;

import wyld.core.ent;
import wyld.core.world;


/// An Ent with basic Stats
abstract class StatEnt : DynamicEnt {
  Stat hp,
       sp,
       thirst,
       hunger;
       
  this(Stat hp, Stat sp, Stat thirst, Stat hunger) {
    this.hp = hp;
    this.sp = sp;
    this.thirst = thirst;
    this.hunger = hunger;
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
}


class Player : StatEnt {
  this() {
    super(Stat(500), Stat(200), Stat(400), Stat(200));
  }
}