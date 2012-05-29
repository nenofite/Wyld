module wyld.main;

import wyld.format;
import wyld.layout;
import wyld.screen;
import wyld.worldgen;

import core.thread: Thread, dur;
import n = ncs.curses;
import std.string: toStringz;
import std.random: uniform;
import m = std.math;

const int viewHeight = 25,
          viewWidth = 25,
          nearbyDist = 25;
          
const int geoSubd = 4,
          geoSize = 5;
          
enum Col {
  TEXT,
  BORDER,
  BLUE,
  GREEN,
  RED,
  YELLOW,
  WHITE,
  BLUE_BG,
  YELLOW_BG,
  RED_BG
}

struct Sym {
  char ch;
  Col color;

  void draw(int y, int x) const {
    n.attrset(n.COLOR_PAIR(color));
    n.mvaddch(y, x, ch);
  }
}

class World {
  Ent player;
  Ent[] movingEnts;
  Grid!(StatCont) stat;
  Grid!(Geo) geos;
  string[] msgs;
  Disp[] disp;
  
  Time time;
  
  struct StatCont {
    Terr terr;
    Ent[] statEnts;
  }

  this() {}

  this(int w, int h) {
    stat = new Grid!(StatCont)(w, h);
  }
  
  int xToGeo(int x) {
    return cast(int) m.round((cast(float) x) * geos.w / stat.w);
  }
  int yToGeo(int y) {
    return cast(int) m.round((cast(float) y) * geos.h / stat.h);
  }
  
  bool inView(int x, int y) {
    x -= player.x - (viewWidth / 2);
    y -= player.y - (viewHeight / 2);
    return (x >= 0 && x < viewWidth && y >= 0 && y < viewHeight); 
  }
  
  Sym baseAt(int x, int y) {
    if (stat.inside(x, y))  
      return stat.get(x, y).terr.sym();

    if (x % 3 == 0)
      return Sym('\'', Col.GREEN);
    if (y % 3 == 0)
      return Sym('-', Col.GREEN);
    return Sym(' ', Col.GREEN);
  }

  Ent[] entsAt(int x, int y) {
    Ent[] ret = stat.get(x, y).statEnts.dup;
    foreach (e; movingEnts) {
      if (e.x == x && e.y == y) ret ~= e;
    }
    return ret;
  }

  bool blockAt(int x, int y) {
    if (!stat.inside(x, y)) return true;
    foreach (e; entsAt(x, y)) {
      if (e.isBlocking) return true;
    }
    if (stat.get(x, y).terr.isBlocking) return true;
    return false;
  }

  int moveCostAt(int x, int y) {
    int cost = stat.get(x, y).terr.moveCost();
    foreach (e; entsAt(x, y)) {
      cost += e.moveCost;
    }
    return cost;
  }

  void update() {
    foreach (e; movingEnts) {
      e.runUpdate(this);
      e.statUpdate();
    }
    time.elapse(1);
  }

  void addStatEnt(Ent e) {
    stat.modify(e.x, e.y, (StatCont c) {
      c.statEnts ~= e;
      return c;
    });
  }
  
  void barMsg(string msg) {
    msgs ~= msg;
  }
  void barMsg(string[] msgs) {
    foreach (m; msgs)
      barMsg(m);
  }
}

abstract class Ent {
  int x, y;
  bool isBlocking;
  int moveCost,  // cost for others on this tile
      speed;  // cost to self
  Stat hp, sp, hunger, thirst;

  Update upd;

  this(int x, int y) {
    this.x = x;
    this.y = y;
  }

  Sym sym();
  Update update(World) { return null; }
  string name();

  void runUpdate(World w) {
    if (upd is null) {
      upd = update(w);
    }
    if (upd !is null) {
      if (upd.run(w)) {
        upd = null;
      }
    }
  }
  
  void statUpdate() {}

  void collMove(int nx, int ny, World w) {
    if (!w.blockAt(nx, ny)) {
      x = nx;
      y = ny;
    }
  }
  void collMoveD(int dx, int dy, World w) {
    collMove(dx + x, dy + y, w);
  }

  Update move(int dx, int dy, World w, void delegate(bool) callback = null) {
    int nx = x + dx,
        ny = y + dy;
    if (w.stat.inside(nx, ny)) {
      int cost = w.moveCostAt(x, y) 
               + w.moveCostAt(nx, ny)
               + speed
               - moveCost; //because moveCastAt() will include this too
      return new Update(cost, (World w) {
        bool succ = !w.blockAt(nx, ny);
        if (succ) {
          x = nx;
          y = ny;
        }
        if (callback !is null)
          callback(succ);
      });
    }
    if (callback !is null)
      callback(false);
    return null;
  }
  Update chmove(int dx, int dy, World w, void delegate(bool) callback = null) {
    if (!w.blockAt(x + dx, y + dy)) {
      return move(dx, dy, w, callback);
    } else {
      return null;
    }
  }
  
  Ent[] nearby(World world) {
    Ent[] ret;
    foreach (e; world.movingEnts) {
      /+auto d = dist(e.x, e.y, x, y);
      if (d < nearbyDist) {
        ret ~= DistEnt(d, e);
      }+/
      if (e !is this) {
        if (m.abs(e.x - x) < nearbyDist && m.abs(e.y - y) < nearbyDist) {
          ret ~= e;
        }
      }
    }
    return ret;
  }
}

class Deer : Ent {
  int destX, destY;
  bool hasDest;
  int moveFailed;

  this(int x, int y) {
    super(x, y);
    isBlocking = true;
    speed = 150;
  }

  Sym sym() {
    return Sym('D', Col.WHITE);
  }

  Update update(World world) {
    if (moveFailed >= 2) {
      hasDest = false;
      moveFailed = 0;
    }
  
    if (x == destX && y == destY) {
      hasDest = false;
    }
    if (hasDest) {
      int mx, my;
      mx = compare(destX, x);
      my = compare(destY, y);
      return move(mx, my, world, (bool succ) {
        if (succ) {
          this.moveFailed = 0;
        } else {
          this.moveFailed++;
        }
      });
    } else {
      int delay = uniform!("[]")(50, 1000);
      return new Update(delay, (World w) {
        for (int i = 0; i < 10; i++) {
          int dx, dy;
          dx = x + uniform!("[]")(-10, 10);
          dy = y + uniform!("[]")(-10, 10);
          if (!world.blockAt(dx, dy)) {
            destX = dx;
            destY = dy;
            hasDest = true;
            break;
          }
        }
      });
    }
  }
  
  string name() { return "deer"; }
}

class Troll : Deer {
  this(int x, int y) {
    super(x, y);
    speed = 500;
  }
  
  Sym sym() {
    return Sym('&', Col.GREEN);
  }
  
  string name() { return "troll"; }
}

class Player : Ent {
  this(int x, int y) {
    super(x, y);
    isBlocking = true;
    speed = 50;
    
    hp = Stat(200);
    sp = Stat(1000);
    hunger = Stat(Time.hours(24));  // 24 hours
    thirst = Stat(Time.hours(6));  // 6 hours
  }

  Sym sym() {
    return Sym('@', Col.BLUE);
  }

  Update update(World world) {
    return null;
  }
  
  void statUpdate() {
    if (hunger > 0)
      hunger--;
    if (thirst > 0)
      thirst--;
  }
  
  string name() { return "you"; }
}

class Grass : Ent {
  this(int x, int y) {
    super(x, y);
    moveCost = 20;
  }
  
  Sym sym() {
    return Sym('"', Col.GREEN);
  }
  
  string name() {
    return "grass";
  }
}

class Tree : Ent {
  this(int x, int y) {
    super(x, y);
    isBlocking = true;
  }

  Sym sym() {
    return Sym('t', Col.GREEN);
  }
  
  string name() { return "tree"; }
}

Terr terr(Terr.Type type) {
  return Terr(type, uniform(0, 5) == 0);
}
struct Terr {
  enum Type {
    DIRT,
    MUD,
    ROCK,
    WATER
  }
  alias Type this;
  
  Type type;
  bool pocked;

  Sym sym() {
    switch (type) {
      case Type.DIRT:
        return Sym(pocked ? ',' : '.', Col.YELLOW);
        break;
      case Type.MUD:
        return Sym(pocked ? '~' : '-', Col.YELLOW);
        break;
      case Type.ROCK:
        return Sym(pocked ? ',' : '.', Col.WHITE);
        break;
      case Type.WATER:
        return Sym('~', Col.BLUE);
        break;
      default:
        throw new Error("Unknown Terr type.");
        break;
    }
  }

  bool isBlocking() const {
    switch (type) {
      case Type.WATER:
        return true;
        break;
      default:
        return false;
        break;
    }
  }

  int moveCost() const {
    switch (type) {
      case Type.DIRT:
      case Type.ROCK:
        return 50;
        break;
      case Type.MUD:
        return 100;
        break;
      case Type.WATER:
        return 500;
        break;
      default:
        throw new Error("No moveCost for bad type.");
        break;
    }
  }
}

class Grid(A) {
  A[][] grid;
  int w, h;

  this(int w, int h) {
    this.w = w;
    this.h = h;
    grid = new A[][](w, h);
  }

  A get(int x, int y) {
    assert(inside(x, y));
    return grid[x][y];
  }
  void set(int x, int y, A a) {
    assert(inside(x, y));
    grid[x][y] = a;
  }
  void modify(int x, int y, A delegate(A) f) {
    auto a = get(x, y);
    set(x, y, f(a));
  }

  void map(A delegate(A) f) {
    foreach (ref col; grid) {
      foreach (ref c; col) {
        c = f(c);
      }
    }
  }
  Grid!(B) mapT(B)(B delegate(A) f) {
    auto ret = new Grid!(B)(w, h);
    foreach (int x, col; grid) {
      foreach (int y, c; col) {
        ret.set(x, y, f(c));
      }
    }
    return ret;
  }
  
  Grid!(A) dup() {
    auto ret = new Grid!(A)(w, h);
    foreach (int x, col; grid) {
      foreach (int y, c; col) {
        ret.set(x, y, c);
      }
    }
    return ret;
  }

  bool inside(int x, int y) const {
    return (x >= 0 && x < w && y >= 0 && y < h);
  }
}

void main() {
  n.initscr();
  scope (exit) n.endwin();
  n.cbreak();
  n.noecho();
  n.keypad(n.stdscr, false);
  n.curs_set(false);
  initColor();
  
  auto world = genWorld(7, 7);
  while (true) {
    int x = uniform(-100, 100),
        y = uniform(-100, 100);
    int mx = world.stat.w / 2,
        my = world.stat.h / 2;
    if (!world.blockAt(x, y)) {
      world.player = new Player(mx + x, my + y);
      break;
    }
  }
  
  world.movingEnts ~= world.player;
  
  for (int i = 0; i < 1000; i++) {
    while (true) {
      int x = uniform(0, world.stat.w),
          y = uniform(0, world.stat.h);
      if (!world.blockAt(x, y)) {
        world.movingEnts ~= new Deer(x, y);
        break;
      }
    }
  }
  
  world.barMsg("One thousand deer");
  world.barMsg("roam this random spread.");
  world.barMsg("Now run around like an idiot");
  world.barMsg("and explore!");
  
  auto stack = new ScrStack();
  stack ~= new MainScreen(world);
  
  while (stack.length > 0) stack.update();
}

void initColor() {
  if (n.has_colors()) {
    n.start_color();
    n.init_pair(Col.TEXT, n.COLOR_WHITE, n.COLOR_BLACK);
    n.init_pair(Col.BORDER, n.COLOR_BLACK, n.COLOR_WHITE);
    n.init_pair(Col.BLUE, n.COLOR_BLUE, n.COLOR_BLACK);
    n.init_pair(Col.GREEN, n.COLOR_GREEN, n.COLOR_BLACK);
    n.init_pair(Col.RED, n.COLOR_RED, n.COLOR_BLACK);
    n.init_pair(Col.YELLOW, n.COLOR_YELLOW, n.COLOR_BLACK);
    n.init_pair(Col.WHITE, n.COLOR_WHITE, n.COLOR_BLACK);
    n.init_pair(Col.BLUE_BG, n.COLOR_WHITE, n.COLOR_BLUE);
    n.init_pair(Col.YELLOW_BG, n.COLOR_WHITE, n.COLOR_YELLOW);
    n.init_pair(Col.RED_BG, n.COLOR_WHITE, n.COLOR_RED);
  } else {
    throw new Error("No color.");
  }
}

void clearLine(int y) {
  n.move(y, 0);
  for (int x = 0; x < n.COLS; x++) {
    n.addch(' ');
  }
}

void clearScreen() {
  for (int y = 0; y < n.LINES; y++) {
    clearLine(y);
  }
}

void remove(A)(ref A[] ls, A elem) {
  A[] ret;
  foreach (a; ls) {
    if (a != elem) ret ~= a;
  }
  ls = ret;
}

int compare(T)(T a, T b) {
  if (a > b)
    return 1;
  else if (a < b)
    return -1;
  else
    return 0;
}

class Update {
  int timeReq;
  void delegate(World) update;

  this(int timeReq, void delegate(World) update) {
    this.timeReq = timeReq;
    this.update = update;
  }

  bool run(World world) {
    timeReq--;
    if (timeReq <= 0) {
      if (update !is null)
        update(world);
      return true;
    }
    return false;
  }
}

struct Time {
  uint periods, pticks;
  
  const uint ticksPerPeriod = hours(12),
             periodsPerMoon = 1,
             moonOffset = 90,
             sunMoonMax = 200,
             dawnDuskTicks = minutes(10);
  
  void elapse(int ticks) {
    pticks += ticks;
    while (pticks >= ticksPerPeriod) {
      periods++;
      pticks -= ticksPerPeriod;
    }
  }
  
  bool isDay() const {
    return periods % 2 == 0;
  }
  
  bool isDawn() const {
    assert(isDay());
    return pticks <= dawnDuskTicks;
  }
  bool isDusk() const {
    assert(isDay());
    return pticks >= ticksPerPeriod - dawnDuskTicks;
  }
  
  uint sun() const {
    return (pticks * sunMoonMax / ticksPerPeriod) % sunMoonMax;
  }
  
  uint moon() const {
    return (periods / periodsPerMoon + moonOffset) % sunMoonMax;
  }
  
  static int hours(int hrs) {
    return hrs * 60 * 60 * 100;
  }
  static int minutes(int mins) {
    return mins * 60 * 100;
  }
  static int seconds(int secs) {
    return secs * 100;
  }
}

enum Dir {
  N,
  NE,
  E,
  SE,
  S,
  SW,
  W,
  NW
}

Dir getDir(int x1, int y1, int x2, int y2) {
  auto angle = m.atan2(cast(real) y2 - y1, cast(real) x2 - x1);
  int oct = cast(int) m.round(angle * 4 / m.PI);
  switch (oct) {
    case -2:
      return Dir.N;
      break;
    case -1:
      return Dir.NE;
      break;
    case 0:
      return Dir.E;
      break;
    case 1:
      return Dir.SE;
      break;
    case 2:
      return Dir.S;
      break;
    case 3:
      return Dir.SW;
      break;
    case 4:
    case -4:
      return Dir.W;
      break;
    case -3:
      return Dir.NW;
      break;
    default:
      throw new Error(format("%d", oct));
      assert(false);
      break;
  }
}

int dist(int x1, int y1, int x2, int y2) {
  return cast(int) m.sqrt(m.abs(x2 - x1) ^^ 2 + m.abs(y2 - y1) ^^ 2);
}

string dirName(Dir d) {
  switch (d) {
    case Dir.N:
      return "NORTH";
      break;
    case Dir.NE:
      return "NORTHEAST";
      break;
    case Dir.E:
      return "EAST";
      break;
    case Dir.SE:
      return "SOUTHEAST";
      break;
    case Dir.S:
      return "SOUTH";
      break;
    case Dir.SW:
      return "SOUTHWEST";
      break;
    case Dir.W:
      return "WEST";
      break;
    case Dir.NW:
      return "NORTHWEST";
      break;
    default:
      assert(false);
      break;  
  }
}

struct Stat {
  uint val, max;
  alias val this;
  
  this(uint val, uint max) {
    this.val = val;
    this.max = max;
  }
  this (uint max) {
    this(max, max);
  }
  
  void draw(uint w = 10) const {
    uint gw = cast(int) (cast(float) val / max * w);
    n.attrset(n.COLOR_PAIR(Col.GREEN));
    for (int i = 0; i < gw; i++) {
      n.addch('=');
    }
    n.attrset(n.COLOR_PAIR(Col.RED));
    for (int i = 0; i < w - gw; i++) {
      n.addch('-');
    }
  }
}

struct Coord {
  int x, y;
  
  void mult(int f) {
    x *= f;
    y *= f;
  }
  
  void add(Coord c) {
    x += c.x;
    y += c.y;
  }
}

Coord getDirKey(char key) {
  bool isKey;
  return getDirKey(key, isKey);
}
Coord getDirKey(char key, ref bool isKey) {
  isKey = true;
  switch (key) {
    case '8':
      return Coord(0, -1);
      break;
    case '9':
      return Coord(1, -1);
      break;
    case '6':
      return Coord(1, 0);
      break;
    case '3':
      return Coord(1, 1);
      break;
    case '2':
      return Coord(0, 1);
      break;
    case '1':
      return Coord(-1, 1);
      break;
    case '4':
      return Coord(-1, 0);
      break;
    case '7':
      return Coord(-1, -1);
      break;
    default:
      isKey = false;
      return Coord(0, 0);
      break;
  }
}

abstract class Skill {
  string name;
  char key;

  Command cmd();
}

abstract class Command {
  string name;
  
  bool takesUsing, takesTo, takesDest, takesDir;
  Ent using, to;
  Coord dest;
  Dir dir;
  
  void run(World);
}

struct Disp {
  Sym sym;
  Coord coord;
}
