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
    super(name, sym, tags, coord, viewRadius, nearbyRadius);
    
    this.hp = hp;
    this.sp = sp;
    this.thirst = thirst;
    this.hunger = hunger;
  }
  
  
  /// Regenerate (and degrade) certain stats over time
  void tickUpdate() {
    if (world.time.ticks % 10 == 0) {
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
        int damage;
        if (rand.uniform!("[]")(0, 4) == 0) {
            damage = cast(int)(attack.damage * rand.uniform!("[]")(2.0, 3.0));
            attack.criticalHit(damage);
        } else {
            damage = attack.damage;
            attack.successfulHit(damage);
        }
        takeDamage(damage);
    } else {
        attack.missHit();
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
  
  SpRequirement spRequirement(int amount) {
    return new SpRequirement(this, amount);
  }
  
  static class SpRequirement : StatRequirement {
    StatEnt ent;
  
    this(StatEnt ent, int amount) {
        super(amount);
        this.ent = ent;
    }
    
    bool check() {
        return amount <= ent.sp;
    }
    
    void consume() {
        ent.sp -= amount;
    }
  }
}


class Player : StatEnt {
  Interaction[] interactions;
  Recipe[] recipes;
  Ent equipped;
  
  uint jumpRadius;

  this(Coord coord) {
    Tags tags;
    
    tags.size = 6000;
    
    tags.isBlocking = true;
    
    tags.containCo = .05;
    
    tags.speed = 50;
    
    jumpRadius = 4;
  
    super("you", Sym('@', Color.Blue), tags, coord, 
          Stat(500), Stat(500), Stat(400), Stat(200), 12, 25);
          
    interactions = [
      new PickUp(),
      new Equip(),
      new Unequip(),
      cast(Interaction) new Drink()
    ];
    
    recipes = [
        new SharpStoneRecipe(),
        cast(Recipe)new SpearRecipe()
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
  
  void attackMove(Direction dir) {
    auto delta = coordFromDirection(dir);
    auto newCoord = coord + delta;
    
    foreach (DynamicEnt ent; world.dynamicEnts) {
        if (ent.coord == newCoord) {
            StatEnt statEnt = cast(StatEnt)ent;
            if (statEnt !is null) {
                if (equipped !is null) {
                    update = (new WeaponAttack(this, statEnt)).update();
                } else {
                    update = (new Punch(this, statEnt)).update();
                }
                return;
            }
        }
    }
    
    update = MoveUpdate.avoiding(this, dir);
  }
  
  Ent corpse() {
    return null;
  }
  
  static class Punch : Attack {
    this(Player from, StatEnt to) {
        super(from, to, Type.Blunt, 4, 8);
    }
    
    Update update() {
        return Attack.update(Time.fromSeconds(1), 10);
    }
    
    Message message() {
        string msg = "You punch " ~ to.name ~ ".";
        return new SimpleCoordMessage(msg, from.coord);
    }
    
    void criticalHit(int damage) {
        menu.addMessage(format("You score a critical hit, dealing %d damage to %s!", damage, to.name));
    }
    
    void successfulHit(int damage) {
        menu.addMessage(format("You land a hit and deal %d damage to %s.", damage, to.name));
    }
    
    void missHit() {
        menu.addMessage("You miss " ~ to.name);
    }
  }
  
  static class WeaponAttack : Attack {
    Ent weapon;
    
    this(Player from, StatEnt to) {
        weapon = from.equipped;
        assert(weapon !is null);
        super(from, to, weapon.tags.damageType, weapon.tags.accuracy, weapon.tags.damage);
    }
    
    Update update() {
        int time = Time.fromSeconds(weapon.tags.weight / 10.0);
        return Attack.update(time, weapon.tags.weight * 5);
    }
    
    Message message() {
        string msg = "You use " ~ weapon.name ~ " on " ~ to.name ~ ".";
        return new SimpleCoordMessage(msg, from.coord);
    }
    
    void criticalHit(int damage) {
        menu.addMessage(format("You score a critical hit, dealing %d damage to %s!", damage, to.name));
    }
    
    void successfulHit(int damage) {
        menu.addMessage(format("You land a hit and deal %d damage to %s.", damage, to.name));
    }
    
    void missHit() {
        menu.addMessage("You miss " ~ to.name);
    }
  }
  
  SpRequirement spRequirement(int amount) {
    return new SpRequirement(this, amount);
  }
  
  static class SpRequirement : StatEnt.SpRequirement {
    this(Player ent, int amount) {
        super(ent, amount);
    }
  
    void onFail() {
        menu.addMessage(format("You do not have enough stamina (requires %d, you have %d).", amount, ent.sp.amount));
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
        update = MoveUpdate.avoiding(this, oppositeDirection(directionBetween(coord, predator.coord)));
      } else {
        if (coord == dest) {
          hasDest = false;
        }
      
        if (hasDest) {
          update = MoveUpdate.avoiding(this, directionBetween(coord, dest));
          
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
    StatEnt prey;
    int howlTimer = -1;
    
    this(Coord coord) {
        Tags tags;
        
        tags.size = 7000;
        
        tags.isBlocking = true;
        
        tags.speed = 40;
    
        super("wolf", Sym('w', Color.Blue), tags, coord, Stat(400), Stat(500), Stat(1000), Stat(200), 20, 50);
    }
    
    void tickUpdate() {
        StatEnt.tickUpdate();
    
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
                foreach (DynamicEnt ent; nearbyEnts()) {
                    StatEnt statEnt = cast(StatEnt)ent;
                    if (statEnt !is null)
                        if ((cast(Deer)statEnt !is null) || (cast(Player)statEnt !is null)) {
                            setPrey(statEnt);
                            break;
                        }
                }
            } else if (distanceBetween(coord, prey.coord) <= 1) {
                update = (new Bite(this, prey)).update();
            } else {
                update = MoveUpdate.avoiding(this, directionBetween(coord, prey.coord));
                if (update is null) {
                    prey = null;
                }
            }
        }
    }
    
    void hearSound(Sound sound) {
        if (prey is null) {
            if (cast(Wolf)sound.ent is null) {
                auto ent = cast(StatEnt)sound.ent;
                if (ent !is null)
                    setPrey(ent);
            }
        }
    }
    
    void setPrey(StatEnt prey) {
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
        this(Wolf from, StatEnt to) {
            super(from, to, Type.Sharp, 5, 15);
        }
        
        Update update() {
            return Attack.update(Time.fromSeconds(1.5), 25);
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
    tags.tie = true;
  
    super("grass", Sym('"', Color.Green), tags, coord);
  }
}


class Tree : Ent {
  this(Coord coord) {
    Tags tags;
    
    tags.size = 24000;
    
    tags.isBlocking = true;
    tags.isAirBlocking = true;
    
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
    Type type;
    int accuracy, damage;
    
    this(StatEnt from, StatEnt to, Type type, int accuracy, int damage) {
        this.from = from;
        this.to = to;
        this.type = type;
        this.accuracy = accuracy;
        this.damage = damage;
    }
    
    Update update(int time, int stamina) {
        return new Update(this, time, stamina);
    }
    
    void apply() {
        to.onAttack(this);
    }
    
    void criticalHit(int damage) {
        string msg = format("%s scores a critical hit on %s, dealing %d damage.", from.name, to.name, damage);
        (new SimpleCoordMessage(msg, from.coord)).broadcast();
    }
    
    void successfulHit(int damage) {
        string msg = format("%s hits %s, dealing %d damage.", from.name, to.name, damage);
        (new SimpleCoordMessage(msg, from.coord)).broadcast();
    }
    
    void missHit() {
        string msg = from.name ~ " misses " ~ to.name ~ ".";
        (new SimpleCoordMessage(msg, from.coord)).broadcast();
    }
    
    abstract Message message();
    
    static class Update : wyld.core.ent.Update {
        Attack attack;
    
        this(Attack attack, int time, int sp) {
            super(time, [], [attack.from.spRequirement(sp)]);
        
            this.attack = attack;
        }
        
        void apply() {
            attack.message().broadcast();
            attack.apply();
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

class Spear : Ent {
    this(Coord coord, int weight = 20, int size = 30) {
        Tags tags;
        tags.size = size;
        tags.weight = weight;
        tags.bigStick = true;
        tags.damage = 10;
        tags.accuracy = 6;
        tags.damageType = Attack.Type.Sharp;

        super("spear", Sym('/', Color.Blue), tags, coord);
    }
}

class SpearRecipe : Recipe {
    BigStickIngredient bigStick;
    TieIngredient tie;
    SharpIngredient sharp;

    this() {
        super("spear", Time.fromMinutes(1));
        bigStick = new BigStickIngredient();
        tie = new TieIngredient();
        sharp = new SharpIngredient();
        ingredients = [bigStick, tie, cast(Ingredient)sharp];
    }
    
    Ent craft() {
        int weight = bigStick.ent.tags.weight +
                     tie.ent.tags.weight +
                     sharp.ent.tags.weight,
            size = bigStick.ent.tags.size +
                   tie.ent.tags.size +
                   sharp.ent.tags.weight;
        return new Spear(Coord(0, 0), weight, size);
    }
}

class Stick : Ent {
    this(Coord coord) {
        Tags tags;
        tags.size = 50;
        tags.weight = 15;
        tags.bigStick = true;
        tags.damage = 8;
        tags.accuracy = 4;
        tags.damageType = Attack.Type.Blunt;
        
        super("wooden stick", Sym('/', Color.Yellow), tags, coord);
    }
}

class JumpTo : Update {
    Coord dest;
    StatEnt ent;
    
    bool failed;
    
    this(Coord dest, StatEnt ent, bool initial = true) {
        this.dest = dest;
        this.ent = ent;
        auto consumes = initial ? [ent.spRequirement(distanceBetween(ent.coord, dest) * 100)] : [];
        super(Time.fromSeconds(1) / 10, [], consumes);
    }
    
    void apply() {
        Coord delta = coordFromDirection(directionBetween(ent.coord, dest));
        auto newCoord = ent.coord + delta;
        if (world.isAirBlockingAt(newCoord)) {
            failed = true;
            menu.addMessage("You slam mid-jump into something.");
        } else
            ent.coord = ent.coord + delta;
    }
    
    Update next() {
        if (!failed && ent.coord != dest) {
            return new JumpTo(dest, ent, false);
        }
        return null;
    }
}

class WalrusFriend : StatEnt {
    int snortDelay;
    Ent follow;

    this(Coord coord, Ent follow) {
        this.follow = follow;
    
        Tags tags;
        tags.size = 12000;
        
        tags.isBlocking = true;
        tags.speed = 50;
        
        super("walrus friend", Sym('W', Color.White), tags, coord,
              Stat(500), Stat(500), Stat(400), Stat(200), 10, 20);
              
        randSnortDelay();
    }
    
    void tickUpdate() {
        StatEnt.tickUpdate();
        
        if (update is null) {
            if (distanceBetween(coord, follow.coord) > 3) {
                auto dir = directionBetween(coord, follow.coord);
                update = MoveUpdate.avoiding(this, dir);
            } else {
                snortDelay--;
                if (snortDelay <= 0) {
                    (new SimpleCoordMessage("The walrus friend snorts at you.", coord)).broadcast();
                
                    randSnortDelay();
                }
            }
        }
    }
    
    void randSnortDelay() {
        snortDelay = Time.fromSeconds(rand.uniform!("[]")(5, 30));
    }
    
    void hearSound(Sound) {}
    
    Ent corpse() {
        return new Corpse(this);
    }
    
    static class Corpse : Ent {
        this(WalrusFriend walrus) {
            auto sym = walrus.sym;
            sym.color = Color.Red;
            super(walrus.name, sym, walrus.tags, walrus.coord);
        }
    }
}

class Sleep : Update {
    static const int pieceLength = Time.fromSeconds(10);

    int remainingPieces;
    StatEnt ent;

    this(int remainingPieces, StatEnt ent) {
        this.remainingPieces = remainingPieces;
        this.ent = ent;
        timeDelta = Time.fromSeconds(10);
        super(pieceLength, [], []);
    }

    static Sleep forTime(int time, StatEnt ent) {
        return new Sleep(time / pieceLength, ent);
    }
    
    static Sleep untilDawn(StatEnt ent) {
        int ticks = Time.fromPeriods(1) - world.time.periodTicks();
        if (world.time.isDay())
            ticks += Time.fromPeriods(1);
        return Sleep.forTime(ticks, ent);
    }
    
    Sleep next() {
        if (remainingPieces > 0) {
            remainingPieces--;
            consumeTime = pieceLength;
            return this;
        } else {
            return null;
        }
    }
    
    void apply() {
        ent.sp.amount += 10;
        ent.hp.amount += 10;
    }
    
    int timeRemaining() {
        return remainingPieces * pieceLength;
    }
}
