/// This contains the game-specific, concrete Ents
module wyld.ent;

import wyld.core.common;
import wyld.core.ent;
import wyld.core.menu;
import wyld.core.world;
import wyld.interactions;
import wyld.main;

import rand = std.random;
import std.format: format;


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
        takeDamage(attack.damage);
    }
  }
  
  
  void takeDamage(int dmg) {
    if (!isDead()) {
        hp -= dmg;
        if (isDead()) onDie();
    }
  }
  
  
  void onDie() {
    (new SimpleCoordMessage(name ~ " dies.", coord)).broadcast();
    auto corpse = corpse();
    world.add(corpse);
    world.remove(this);
  }
  
  
  abstract Ent corpse();
   
  
  bool isDead() {
    return hp == 0;
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
  Recipe[] recipes;

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
    
    recipes = [
        new SharpStoneRecipe()
    ];
  }
  
  void hearSound(Sound sound) {
    menu.addMessage(sound.message());
  }
  
  void takeDamage(int dmg) {
    StatEnt.takeDamage(dmg);
    menu.addMessage(format("You take %d damage.", dmg));
  }
  
  void onDie() {
    menu.addMessage("You have died.");
    menu.running = false;
  }
  
  void attackMove(Coord delta) {
    auto newCoord = coord + delta;
    
    foreach (DynamicEnt ent; world.dynamicEnts) {
        if (ent.coord == newCoord) {
            StatEnt statEnt = cast(StatEnt)ent;
            if (statEnt !is null) {
                update = (new Punch(this, statEnt)).update();
                return;
            }
        }
    }
    
    move(delta);
  }
  
  Ent corpse() {
    return null;
  }
  
  static class Punch : Attack {
    Player from;
    
    this(Player from, StatEnt to) {
        this.from = from;
        this.to = to;
        type = Type.Blunt;
        damage = 8;
        accuracy = 4;
    }
    
    Update update() {
        return Attack.update(100);
    }
    
    Message message() {
        string msg = "You punch " ~ to.name ~ ".";
        return new SimpleCoordMessage(msg, from.coord);
    }
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
  
  
  static class ScreamSound : Sound {
    this(Deer deer) {
      super("screaming", Mood.Neutral, 300, deer);
    }
  }
  
  static class Corpse : Ent {
    this(Deer deer) {
        super("deer corpse", Sym('D', Color.Red), deer.tags, deer.coord);
    }
  }

  Corpse corpse() {
    return new Corpse(this);
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
        if (prey is null) {
            howlTimer--;
            
            if (howlTimer == 0) {
                (new HowlSound(this)).broadcast();
            } else if (howlTimer < 0) {
                howlTimer = rand.uniform(Time.fromMinutes(1), Time.fromMinutes(5));
            }
        } else {
            howlTimer = -1;
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
//        (new GrowlSound(this)).broadcast();
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
            accuracy = 5;
            damage = 15;
        }
        
        Update update() {
            return Attack.update(150);
        }
        
        Message message() {
            string msg = from.name ~ " bites at " ~ to.name ~ ".";
            return new SimpleCoordMessage(msg, from.coord);
        }
    }
    
    static class Corpse : Ent {
      this(Wolf wolf) {
          super("wolf corpse", Sym('w', Color.Red), wolf.tags, wolf.coord);
      }
    }
    
    Corpse corpse() {
        return new Corpse(this);
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

abstract class Recipe {
    string name;
    int time;
    
    Ingredient[] ingredients, tools;
    
    this(string name, int time) {
        this.name = name;
        this.time = time;
    }
    
    abstract Ent craft();
    
    void clearIngredients() {
        foreach (Ingredient ing; ingredients) {
            ing.ent = null;
        }
        foreach (Ingredient ing; tools) {
            ing.ent = null;
        }
    }
}

class SharpStoneRecipe : Recipe {
    UnsharpStone unsharpStone;
    ClassIngredient!Stone toolStone;

    this() {
        super("sharpen stone", Time.fromMinutes(1));
        unsharpStone = new UnsharpStone();
        toolStone = new ClassIngredient!Stone();
        ingredients = [unsharpStone];
        tools = [toolStone];
    }

    Stone craft() {
        Stone stone = cast(Stone)unsharpStone.ent;
    
        stone.sharpen();
        return stone;
    }
}

class UnsharpStone : Ingredient {
    this() {
        super("unsharpened stone");
    }
    
    bool canTake(Ent ent) {
        Stone stone = cast(Stone)ent;
        return stone !is null && !stone.tags.sharp;
    }
}

class Stone : Ent {
    this(int size, Coord coord) {
        Tags tags;
        tags.size = size;
        tags.weight = size / 5 + 1;
    
        super("stone", Sym('o', Color.White), tags, coord);
    }
    
    void sharpen() {
        tags.sharp = true;
        name = "sharp stone";
        sym.sym = 'x';
    }
}

abstract class Ingredient {
    string name;
    Ent ent;
    
    this(string name) {
        this.name = name;
    }
    
    abstract bool canTake(Ent);
}

class ClassIngredient(T) : Ingredient {
    this() {
        super("<class>");
    }
    
    bool canTake(Ent ent) {
        return cast(T)ent !is null;
    }
}

class BigStickIngredient : Ingredient {
    this() {
        super("big stick");
    }
    
    bool canTake(Ent ent) {
        return ent.tags.bigStick;
    }
}

class SharpIngredient : Ingredient {
    this() {
        super("sharp");
    }
    
    bool canTake(Ent ent) {
        return ent.tags.sharp;
    }
}

class TieIngredient : Ingredient {
    this() {
        super("tie");
    }
    
    bool canTake(Ent ent) {
        return ent.tags.tie;
    }
}
