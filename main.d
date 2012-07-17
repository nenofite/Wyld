module main;

import alg = std.algorithm;
import std.array: appender;
import std.conv: ConvException;
import std.format: formattedRead, formattedWrite;
import math = std.math;
import rand = std.random;
import std.stdio;
import std.string: chomp, toStringz;


Game game;
Player player;


/// Separates a string of words separated by spaces into a list of those
/// words
///
/// ---
/// assert(words("  bob billo  hoi ") == ["bob", "billo", "hoi"]);
/// ---
string[] words(string clump) {
  /// Start with a single, empty word
  string[] words = [""];

  /// Go through each character
  foreach (c; clump) {
    /// If it's a space, start on the next word
    if (c == ' ') {
      if (words[$-1].length > 0) {
        words ~= "";
      }
    } else {
      /// Otherwise, append it to the current word
      words[$-1] ~= c;
    }
  }

  /// If there is a leftover empty word on the end, drop it
  if (words[$-1].length == 0) {
    words = words[0 .. $-1];
  }

  return words;
}


/// The game world and shtuff
class Game : Location {
  Time time;
  Command[] commands;


  this() {
    time = new Time();
  }


  void loop() {
    while (true) {
      foreach (ent; game.contained) {
        ent.statUpdate();

        if (ent.update !is null) {
          auto isDone = ent.update.run();

          if (isDone) {
            ent.update = null;
          }
        }
      }

      game.time.increment();
    }
  }


  string read(string prompt = "> ") {
    write(prompt);
    stdout.flush();

    return chomp(readln());
  }


  void put(string msg) {
    writeln(msg);
  }


  void prompt(A...)(string msg, const string fmt, A args) {
    while (true) {
      game.put(msg);

      auto input = game.read("? ");
      auto success = scan(input, fmt, args);

      if (success) {
        return;
      } else {
        game.put("Invalid choice.");
      }
    }
  }
}


/// Keeps track of in-game time
class Time {
  int ticks;


  void increment() {
    ++ticks;
  }


  static int fromSeconds(int seconds) {
    return seconds * 100;
  }


  static int fromMinutes(int minutes) {
    return fromSeconds(minutes * 60);
  }
}


/// Something that contains other Ents
abstract class Location {
  Entity[] contained;


  void add(Entity ent) {
    contained ~= ent;
  }


  void remove(Entity ent) {
    contained.remove(ent);
    ent.location = null;
  }
}


/// Removes the first occurence of the given item from the list
void remove(T)(ref T[] list, T item) {
  T[] newList = new T[](list.length - 1);

  bool found;
  foreach (i, a; list) {
    if (!found && a is item) {
      found = true;
    } else if (found) {
      newList[i-1] = a;
    } else {
      newList[i] = a;
    }
  }

  assert(found, "Element not found in list.");

  list = newList;
}


abstract class Entity : Location {
  string keyword;
  Name name;
  Location location;
  int weight;
  HitMethod[] hitMethods;

  Update update;


  this(string keyword, Name name) {
    this.keyword = keyword;
    this.name = name;
  }


  void statUpdate() {}


  bool isWeapon() {
    return (hitMethods.length > 0);
  }
}


struct Name {
  string singular;
  string posessive;
}


abstract class Update {
  int time;

  this(int time) {
    this.time = time;
  }


  bool run() {
    if (time > 0) {
      --time;

      return false;
    } else {
      apply();

      return true;
    }
  }


  void apply();
}


abstract class Creature : Entity {
  Stat stamina;
  int strength;
  int coordination;
  BodyPart torso;
  bool isAlive = true;

  this(string keyword, Name name, Stat stamina, int strength, int coordination, BodyPart torso) {
    super(keyword, name);

    this.stamina = stamina;
    this.strength = strength;
    this.coordination = coordination;
    this.torso = torso;
  }

  void statUpdate() {
    if (game.time.ticks % 100 == 0) {
      ++stamina;
    }
  }

  int expendableStamina() {
    return alg.min(strength, stamina.amount);
  }

  void die() {
    if (isAlive) {
      game.put(fmt("%s has died.", name.singular));
    }

    isAlive = false;
  }
}


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
}


class BodyPart : Entity {
  Stat hp;
  int size;
  bool isCritical;
  Tags tags;
  Creature creature;
  BodyPart parent;
  BodyPart[] children;

  this(string keyword, Name name, Stat hp, int size, bool isCritical, Tags tags, BodyPart[] children) {
    super(keyword, name);
    this.hp = hp;
    this.size = size;
    this.isCritical = isCritical;
    this.tags = tags;
    this.children = children;
  }


  BodyPart[] mirror(string[] prefixes) {
    static BodyPart addPrefix(string prefix, BodyPart part) {
      auto dup = new BodyPart(prefix ~ part.keyword,
                              Name(prefix ~ part.name.singular, prefix ~ part.name.posessive),
                              part.hp,
                              part.size,
                              part.isCritical,
                              part.tags,
                              part.children.dup);

      foreach (ref children; dup.children) {
        children = addPrefix(prefix, children);
      }
      
      dup.weight = part.weight;
      
      dup.hitMethods = part.hitMethods.dup;

      return dup;
    }

    BodyPart[] list;

    foreach (prefix; prefixes) {
      prefix ~= " ";

      list ~= addPrefix(prefix, this);
    }

    return list;
  }


  /// Recursively go through all children of this BodyPart and set their
  /// parent fields accordingly.
  void linkChildren(Creature creature) {
    this.creature = creature;

    foreach (child; children) {
      child.parent = this;

      child.linkChildren(creature);
    }
  }


  void removePart(BodyPart child) {
    children.remove(child);

    child.parent = null;
  }


  void die() {
    game.put(fmt("%s %s has been completely destroyed.", creature.name.posessive, name.singular));

    if (isCritical) {
      creature.die();
    }
  }


  static struct Tags {
    bool canSee;

    bool canHold;
    Entity held;
  }
}


/// A way of attacking using a Weapon
class HitMethod {
  string name;
  int hitArea;
  float transfer;

  this(string name, int hitArea, float transfer) {
    this.name = name;
    this.hitArea = hitArea;
    this.transfer = transfer;
  }
}


abstract class Command {
  string keyword;

  this(string keyword) {
    this.keyword = keyword;
  }


  void run(Parameters);


  static class Parameters {
    string[] words;
    int index;

    this(string[] words) {
      this.words = words;
    }


    bool readEntity(ref Entity ent) {
      if (index >= words.length) {
        return false;
      }

      ent = matchKeyword(game.contained, words[index]);

      ++index;

      return (ent !is null);
    }


    int choose(string prompt, string[] choices) {
      while (true) {
        game.put(prompt);

        foreach (int i, choice; choices) {
          game.put(fmt("%s) %s", i + 1, choice));
        }

        int choice;
        bool worked = scan(game.read("# "), "%s", &choice);

        --choice;

        if (worked && choice >= 0 && choice < choices.length) {
          return choice;
        } else {
          game.put("Invalid choice.");
        }
      }
    }
  }
}


abstract class Function {

}


class Grasp : Function {
  Entity held;
}


class See : Function {

}


string fmt(A...)(const string fmt, A args) {
  auto writer = appender!(string)();
  formattedWrite(writer, fmt, args);
  return writer.data;
}


bool scan(A...)(string input, const string fmt, A args) {
  uint result;

  try {
    result = formattedRead(input, fmt, args);
  } catch (ConvException e) {
    return false;
  }

  return (result == args.length);
}


class Player : Creature {
  this(Stat stamina, int strength, int coordination) {
    auto torso = new BodyPart("torso", Name("torso", "torso's"), Stat(100), 220, true, BodyPart.Tags(), [
      new BodyPart("head", Name("head", "head's"), Stat(20), 40, true, BodyPart.Tags(),
        (new BodyPart("eye", Name("eye", "eye's"), Stat(10), 4, false, BodyPart.Tags(true), [])).mirror(["left", "right"]))
    ]);

    auto hand = new BodyPart("hand", Name("hand", "hand's"), Stat(20), 18, false, BodyPart.Tags(false, true), []);
    hand.weight = 5;
    hand.hitMethods = [
      new HitMethod("punch", 12, .6),
      new HitMethod("slap", 14, .4)
    ];

    torso.children ~= (new BodyPart("arm", Name("arm", "arm's"), Stat(30), 40, false, BodyPart.Tags(), [hand])).mirror(["left", "right"]);

    torso.children ~= (new BodyPart("leg", Name("leg", "leg's"), Stat(40), 120, false, BodyPart.Tags(), [
      new BodyPart("foot", Name("foot", "foot's"), Stat(20), 26, false, BodyPart.Tags(), [])
    ])).mirror(["left", "right"]);

    torso.linkChildren(this);

    super("me", Name("you", "your"), stamina, strength, coordination, torso);
  }


  void statUpdate() {
    Creature.statUpdate();

    if (update is null) {
      auto input = words(game.read());

      if (input.length > 0) {
        auto cmd = matchKeyword(game.commands, input[0]);

        if (cmd !is null) {
          string[] args;

          if (input.length > 1) {
            args = input[1 .. $];
          }

          cmd.run(new Command.Parameters(args));
        } else {
          game.put("What you talkin bout?");
        }
      }
    }
  }
}


class Wolf : Creature {
  this() {
    auto torso = new BodyPart("torso", Name("torso", "torso's"), Stat(100), 220, true, BodyPart.Tags(), [
      new BodyPart("head", Name("head", "head's"), Stat(20), 40, true, BodyPart.Tags(),
        (new BodyPart("eye", Name("eye", "eye's"), Stat(10), 4, false, BodyPart.Tags(true), [])).mirror(["left", "right"]))
    ]);

    torso.children ~= (new BodyPart("leg", Name("leg", "leg's"), Stat(50), 100, false, BodyPart.Tags(), [
      new BodyPart("foot", Name("foot", "foot's"), Stat(20), 40, false, BodyPart.Tags(), [])
    ])).mirror(["front left", "front right", "back left", "back right"]);

    torso.linkChildren(this);

    super("wolf", Name("wolf", "wolf's"), Stat(15), 9, 7, torso);
  }


  void statUpdate() {
    Creature.statUpdate();

    if (isAlive) {
      if (update is null) {
        update = new GenUpdate(Time.fromSeconds(1), () {
          if (isAlive) {
            game.put("Erhmahgerd werf!");
          }
        });
      }
    }
  }
}


class SetupCommand : Command {
  this() {
    super("");
  }


  void run(Command.Parameters) {
    game.put("Enter your stats:\n");

    Stat stamina;
    game.prompt("Stamina:", "%d/%d", &stamina.amount(), &stamina.max);

    int strength;
    game.prompt("Strength:", "%d", &strength);

    int coordination;
    game.prompt("Coordination:", "%d", &coordination);

    game.put("");

    player = new Player(stamina, strength, coordination);

    game.add(player);


  }
}


/// Matches among any type that has the string 'keyword' in it
K matchKeyword(K)(K[] list, string keyword) {
  auto matches = list;

  /// Go through the chars of the keyword and chop off Ents that
  /// don't match it
  foreach (int i, c; keyword) {
    K[] newMatches;

    foreach (k; matches) {
      if (k.keyword.length > i) {
        if (k.keyword[i] == c) {
          newMatches ~= k;
        }
      }
    }

    matches = newMatches;
  }

  if (matches.length > 0) {
    return matches[0];
  } else {
    return null;
  }
}


class LookCommand : Command {
  this() {
    super("look");
  }


  void run(Command.Parameters params) {
    Entity target;
    auto isTargeted = params.readEntity(target);

    if (isTargeted) {
      game.put(fmt("%s:", target.name.singular));

      auto creature = cast(Creature) target;

      if (creature !is null) {
        assert(creature.torso !is null);

        foreach (part; allParts(creature.torso)) {
          string output = part.name.singular ~ "\t" ~ hpName(part.hp);

          if (part.tags.canHold) {
            if (part.tags.held !is null) {
              output ~= "\tHolding: " ~ part.tags.held.name.singular;
            } else {
              output ~= "\tCan hold";
            }
          }

          game.put(output);
        }
      }
    } else {
      game.put(fmt("Here there is %(%s, %).", game.contained));

      if (player.contained.length > 0) {
        game.put(fmt("You are holding %(%s, %).", player.contained));
      }
    }
  }
}


class GrabCommand : Command {
  this() {
    super("grab");
  }


  void run(Command.Parameters params) {
    Entity target;
    auto isTargeted = params.readEntity(target);

    if (isTargeted) {
      BodyPart[] hands;

      foreach (part; allParts(player.torso)) {
        if (part.tags.canHold) {
          hands ~= part;
        }
      }

      string[] strHands = new string[](hands.length);

      foreach (int i, ref str; strHands) {
        str = hands[i].name.singular ~ "\t";

        if (hands[i].tags.held !is null) {
          str ~= "Holding: " ~ hands[i].tags.held.name.singular;
        } else {
          str ~= "Empty";
        }
      }

      auto choice = params.choose("Grab with which hand:", strHands);

      if (hands[choice].tags.held !is null) {
        game.add(hands[choice].tags.held);
        game.put("You drop " ~ hands[choice].tags.held.name.singular);
      }

      player.update = new GenUpdate(100, () {
        game.remove(target);
        hands[choice].tags.held = target;

        game.put("You pick up " ~ target.name.singular);
      });
    } else {
      game.put("Must specify a target.");
    }
  }
}


class WaitCommand : Command {
  this() {
    super("wait");
  }


  void run(Command.Parameters params) {
    int tenthSecs;
    game.prompt("How many tenths of a second?", "%d", &tenthSecs);

    player.update = new GenUpdate(tenthSecs * 10, () {});
    game.put("You wait.");
  }
}


class AttackCommand : Command {
  this() {
    super("attack");
  }


  void run(Command.Parameters params) {
    Creature target;

    {
      Entity ent;

      auto hasTarget = params.readEntity(ent);

      target = cast(Creature) ent;

      if (!hasTarget || target is null) {
        game.put("Need creature target");
        return;
      }
    }

    struct WeaponHitMethod {
      Entity weapon;
      HitMethod hitMethod;
    }

    WeaponHitMethod hitMethod;

    {
      /// Choose weapon and hit method
      WeaponHitMethod[] hitMethods;
      string[] strHitMethods;

      foreach (part; allParts(player.torso)) {
        if (part.tags.canHold && part.tags.held !is null) {
          auto weapon = part.tags.held;

          if (weapon.isWeapon) {
            foreach (method; weapon.hitMethods) {
              hitMethods ~= WeaponHitMethod(weapon, method);
              strHitMethods ~= fmt("%s w/ %s - area: %s in^2, transfer: %s, weight: %s lbs",
                                   method.name,
                                   weapon.name.singular,
                                   method.hitArea,
                                   method.transfer,
                                   weapon.weight);
            }
          }
        }
        
        foreach (method; part.hitMethods) {
          hitMethods ~= WeaponHitMethod(part, method);
          strHitMethods ~= fmt("%s w/ %s - area: %s in^2, transfer: %s, weight: %s lbs",
                                   method.name,
                                   part.name.singular,
                                   method.hitArea,
                                   method.transfer,
                                   part.weight);
        }
      }

      auto choice = params.choose("Choose method:", strHitMethods);

      hitMethod = hitMethods[choice];
    }

    BodyPart targetPart;

    {
      /// Choose body part to target
      BodyPart[] parts = allParts(target.torso);
      string[] strParts = new string[](parts.length);

      foreach (int i, part; parts) {
        strParts[i] = fmt("%s (%s) - %s in^2, %s%% %s%%",
                          part.name.singular,
                          hpName(part.hp),
                          part.size,
                          toPercent(probFullHit(hitMethod.weapon, hitMethod.hitMethod, player.coordination, part)),
                          toPercent(probFullMiss(hitMethod.weapon, hitMethod.hitMethod, player.coordination, part)));
      }

      auto choice = params.choose(hitMethod.hitMethod.name ~ " where:", strParts);

      targetPart = parts[choice];
    }

    int sp;

    while (true) {
      game.prompt(fmt("Expending how many SPs? min: %s, max: %s", minSp(hitMethod.weapon), player.expendableStamina), "%d", &sp);

      if (sp >= minSp(hitMethod.weapon) && sp <= player.expendableStamina) {
        break;
      } else {
        game.put("Not within range.");
      }
    }

    auto dmg = cast(int) calcDamage(hitMethod.weapon, hitMethod.hitMethod, player.coordination, targetPart, sp);

    game.put(fmt("Will take %d", calcTime(hitMethod.weapon, hitMethod.hitMethod, sp)));
    player.stamina -= sp;

    player.update = new GenUpdate(calcTime(hitMethod.weapon, hitMethod.hitMethod, sp), () {
      modifyHp(targetPart, -dmg);
    });


    /+game.put(fmt("You do %s damage to %s %s, leaving %s HPs.", dmg, target.name.posessive, targetPart.name.singular, targetPart.hp));

    if (targetPart.hp.amount == 0) {
      game.put("It falls off!");
    }

    player.stamina -= sp;
    game.put(fmt("\nYou are left with %s SPs.", player.stamina));+/
  }
}


float probFullHit(Entity weapon, HitMethod hitMethod, int coordination, BodyPart target) {
  return (target.size - hitMethod.hitArea) /
         (100 / coordination);
}


float probFullMiss(Entity weapon, HitMethod hitMethod, int coordination, BodyPart target) {
  return (1 - (target.size / (100 / coordination)));
}


float calcDamage(Entity weapon, HitMethod hitMethod, int coordination, BodyPart target, int sp) {
  auto leftpoint = rand.uniform(0, 100) / player.coordination;
  auto rightpoint = leftpoint + hitMethod.hitArea;

  float effectiveness;

  if (leftpoint >= target.size) {
    effectiveness = 0;
  } else if (rightpoint <= target.size) {
    effectiveness = 1;
  } else {
    effectiveness = (target.size - leftpoint) / hitMethod.hitArea;
  }

  auto force = (sp - minSp(weapon) + 1) * minSp(weapon) * hitMethod.transfer * effectiveness;

  return force * 10 / hitMethod.hitArea;
}


int calcTime(Entity weapon, HitMethod hitMethod, int sp) {
  int time = weapon.weight * 5;

  if (time < 50) return 50;

  return weapon.weight * 5;
}


int minSp(Entity weapon) {
  return cast(int) weapon.weight / 10;
}


float toPercent(float frac) {
  if (frac <= 0) return 0;
  if (frac >= 1) return 100;

  int thousands = cast(int) frac * 1000;

  return thousands / 10;
}


BodyPart[] allParts(BodyPart base) {
  auto parts = [base];

  foreach (part; base.children) {
    parts ~= allParts(part);
  }

  return parts;
}


string hpName(Stat hp) {
  if (hp == 0) {
    return "gone";
  }

  float ratio = hp / hp.max;

  if (ratio >= .75) {
    return "fine";
  } else if (ratio >= .5) {
    return "light";
  } else if (ratio >= .25) {
    return "moderate";
  } else {
    return "severe";
  }
}


class GenUpdate : Update {
  void delegate() applyF;

  this(int time, void delegate() applyF) {
    super(time);

    this.applyF = applyF;
  }


  void apply() {
    if (applyF !is null) {
      applyF();
    }
  }
}


class HeavyStick : Entity {
  this() {
    super("stick", Name("heavy stick", "heavy stick's"));

    weight = 20;
    hitMethods = [
      new HitMethod("whack", 6, 0.6),
      new HitMethod("jab", 2, 0.8)
    ];
  }
}


void modifyHp(BodyPart part, int hpDelta) {
  part.hp += hpDelta;

  if (part.hp > 0) {
    string changeVerb;

    if (hpDelta > 0) {
      changeVerb = "heals";
    } else {
      changeVerb = "loses";
      hpDelta = -hpDelta;
    }

    game.put(fmt("%s %s %s %s HPs.", part.creature.name.posessive, part.name.singular, changeVerb, hpDelta));
  } else {
    part.die();
  }
}


void main() {
  game = new Game();

  game.commands = [
    new LookCommand(),
    new AttackCommand(),
    new WaitCommand(),
    cast(Command) new GrabCommand()
  ];

  auto setup = new SetupCommand();
  setup.run(new Command.Parameters([]));

  game.add(new HeavyStick());

  game.add(new Wolf());

  game.loop();
}

