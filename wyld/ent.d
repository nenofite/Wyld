/// This contains the game-specific, concrete Ents
module wyld.ent;

import wyld.core.common;
import wyld.core.ent;
import wyld.core.menu;
import wyld.core.world;
import wyld.interactions;
import wyld.main;

import rand = std.random;


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
  
  
  void onAttack(Attack attack) {
    if (rand.uniform!("[]")(0, 10) <= attack.accuracy) {
        hp -= attack.damage;
    }
  }
  
  
  bool move(Coord delta) {
    update = MoveUpdate.withCheck(this, delta);
    
    if (update !is null) {
      update.consumeStats ~= StatRequirement(&sp, 1);
      return true;
    }
    return false;
  }
  
  DynamicEnt[] entsSeen() {
    return world.dynamicEntsInRadius(nearbyRadius, coord);
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
  
  void hearSound(Sound sound) {
    menu.addMessage(sound.message());
  }
}


class Deer : StatEnt {
  Coord dest;
  bool hasDest;
  DynamicEnt predator;

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
      if (predator !is null) {
        if (distanceBetween(coord, predator.coord) > nearbyRadius) predator = null;
      }
      
      if (predator !is null) {
        auto delta = coordFromDirection(oppositeDirection(directionBetween(coord, predator.coord)));
        move(delta);
      } else {
        if (coord == dest) {
          hasDest = false;
        }
      
        if (hasDest) {
          auto delta = coordFromDirection(directionBetween(coord, dest));
          move(delta);
          
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
  
  void hearSound(Sound sound) {
    if (cast(Wolf)sound.ent !is null) {
        predator = cast(DynamicEnt)sound.ent;
    }
  }
  
  class ScreamSound : Sound {
    this(Deer deer) {
      super("screaming", Mood.Neutral, 300, deer);
    }
  }
}


class Wolf : StatEnt {
    DynamicEnt prey;
    int howlTimer = -1;
    
    this(Coord coord) {
        Tags tags;
        
        tags.size = 7000;
        
        tags.isBlocking = true;
        
        tags.speed = 40;
    
        super("wolf", Sym('w', Color.Blue), tags, coord, Stat(400), Stat(500), Stat(1000), Stat(200), 20, 50);
    }
    
    void tickUpdate() {
        howlTimer--;
        
        if (howlTimer == 0) {
            (new HowlSound(this)).broadcast();
        } else if (howlTimer < 0) {
            howlTimer = rand.uniform(Time.fromMinutes(1), Time.fromMinutes(30));
        }
    
        if (update is null) {
            if (prey !is null) {
                if (distanceBetween(coord, prey.coord) > nearbyRadius) {
                    prey = null;
                }
            }
        
            if (prey is null) {
                auto seen = entsSeen();
                
                foreach (DynamicEnt ent; seen) {
                    if ((cast(Deer)ent !is null) || (cast(Player)ent !is null)) {
                        setPrey(ent);
                        break;
                    }
                }
            } else if (distanceBetween(coord, prey.coord) <= 1) {
                update = (new Bite(this, cast(StatEnt)prey)).update();
            } else {
                auto delta = coordFromDirection(directionBetween(coord, prey.coord));
                if (!move(delta)) {
                    prey = null;
                }
            }
        }
    }
    
    void hearSound(Sound sound) {
        if (prey is null) {
            if (cast(Wolf)sound.ent is null) {
                setPrey(cast(DynamicEnt)sound.ent);
            }
        }
    }
    
    void setPrey(DynamicEnt prey) {
        this.prey = prey;
        (new GrowlSound(this)).broadcast();
    }
    
    class HowlSound : Sound {
        this(Wolf wolf) {
            super("howling", Mood.Neutral, 20000, wolf);
        }
    }
    
    class GrowlSound : Sound {
        this(Wolf wolf) {
            super("growling", Mood.Aggressive, 100, wolf);
        }
    }
    
    class Bite : Attack {
        Wolf from;
        
        this(Wolf from, StatEnt to) {
            this.from = from;
            this.to = to;
            type = Type.Sharp;
        }
        
        Update update() {
            return Attack.update(150);
        }
        
        Message message() {
            string msg = from.name ~ " bites at " ~ to.name ~ ".";
            return new SimpleCoordMessage(msg, from.coord);
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

abstract class Attack {
    static enum Type {
        Sharp,
        Blunt
    }
    
    StatEnt from, to;
    int accuracy, damage;
    Type type;
    
    Update update(int time) {
        return new Update(this, time);
    }
    
    void apply() {
        to.onAttack(this);
    }
    
    abstract Message message();
    
    static class Update : wyld.core.ent.Update {
        Attack attack;
    
        this(Attack attack, int time) {
            super(time, [], []);
        
            this.attack = attack;
        }
        
        void apply() {
            attack.apply();
            attack.message().broadcast();
        }
    }
}

abstract class CoordMessage : Message {
    Coord source;
    
    void broadcast() {
        if (distanceBetween(source, player.coord) <= player.viewRadius) {
            Message.broadcast();
        }
    }
}

class SimpleCoordMessage : CoordMessage {
    string msg;
    
    this(string msg, Coord source) {
        this.msg = msg;
        this.source = source;
    }
    
    string text() {
        return msg;
    }
}
