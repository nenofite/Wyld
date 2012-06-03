module wyld.main;

import wyld.format;
import wyld.layout;
import wyld.screen;
import wyld.menu;
import wyld.worldgen;

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
  YELLOW_BBG,
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
  Player player;
  ContainerList movingEnts;
  Grid!(StatCont) stat;
  Grid!(Geo) geos;
  string[] msgs;
  Disp[] disp;
  
  Time time;
  
  static class StatCont {
    Terr terr;
    ContainerList statEnts;
    Tracks tracks;
    
    this() {
      statEnts = new ContainerList();
    }
    this(Terr terr) {
      this();
      this.terr = terr;
    }
  }

  this() {
    movingEnts = new ContainerList();
  }

  this(int w, int h) {
    this();
    stat = new Grid!(StatCont)(w, h);
    stat.map((StatCont) { return new StatCont(); });
  }
  
  void addTracks(Ent source, Dir dir) {
    stat.get(source.x, source.y).tracks = Tracks(time.pticks, source, dir, source.trackNum++);
  }
  
  int xToGeo(int x) {
    return cast(int) m.floor((cast(float) x) * geos.w / stat.w);
  }
  int yToGeo(int y) {
    return cast(int) m.floor((cast(float) y) * geos.h / stat.h);
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
    Ent[] newEnts;
  
    foreach (e; movingEnts) {
      auto res = e.runUpdate(this);
      auto keep = res.keep;
      newEnts ~= res.add;
      
      res = e.statUpdate(this);
      newEnts ~= res.add;
      assert(res.next is null);
      keep = keep && res.keep;
      
      if (keep) newEnts ~= e;
    }
    time.elapse(1);
    movingEnts = newEnts;
  }

  void addStatEnt(Ent e) {
    auto s = stat.get(e.x, e.y);
    s.statEnts.add(e);
    assert(e.parent is null);
    e.parent = s.statEnts;
  }
  
  void barMsg(string msg) {
    msgs ~= msg;
  }
  void barMsg(string[] msgs) {
    foreach (m; msgs)
      barMsg(m);
  }
  
  Ent[] entsNear(int x, int y) {
    Ent[] ret;
    for (int tx = x-1; tx <= x+1; tx++) {
      for (int ty = y-1; ty <= y+1; ty++) {
        if (stat.inside(tx, ty)) {
          ret ~= entsAt(tx, ty);
          auto terrEnt = stat.get(tx, ty).terr.contains;
          if (terrEnt !is null) ret ~= terrEnt;
        }
      }
    }
    return ret;
  }
}

abstract class Ent {
  int x, y;
  bool isBlocking;
  int moveCost,  // cost for others on this tile
      speed;  // cost to self
  Stat hp, sp, hunger, thirst;
  uint trackNum;
  
  Container parent;
  Tags tags;
  alias tags this;

  Update upd;

  this(int x, int y, Container parent) {
    this.x = x;
    this.y = y;
    this.parent = parent;
  }

  Sym sym();
  Update update(World) { return null; }
  string name();
  
  Container.AddRet reparent(Container newParent) {
    auto remRes = parent.remove(this);
    assert(remRes); // TODO properly handle this
    auto res = newParent.add(this);
    if (res == Container.AddRet.SUCCESS) {
      parent = newParent;
    } else {
      auto res2 = parent.add(this);
      assert(res2 == Container.AddRet.SUCCESS);
    }
    return res;
  }

  Update.Ret runUpdate(World w) {
    if (upd is null) {
      upd = update(w);
    }
    
    if (upd !is null) {
      upd.timeReq--;
      if (upd.timeReq <= 0) {
        auto res = upd.update(w);
        upd = res.next;
        return res;
      }
    }
    
    return Update.Ret();
  }
  
  Update.Ret statUpdate(World) { return Update.Ret(); }

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
      return mkUpdate(cost, (World w) {
        bool succ = !w.blockAt(nx, ny);
        if (succ) {
          if (tags.isWalking)
            w.addTracks(this, coordToDir(Coord(dx, dy)));
          x = nx;
          y = ny;
        }
        if (callback !is null)
          callback(succ);
        return Update.Ret();
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

  this(int x, int y, Container parent) {
    super(x, y, parent);
    isBlocking = true;
    speed = 150;
    tags.isWalking = true;
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
      return mkUpdate(delay, (World w) {
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
  this(int x, int y, Container parent) {
    super(x, y, parent);
    speed = 500;
  }
  
  Sym sym() {
    return Sym('&', Col.GREEN);
  }
  
  string name() { return "troll"; }
}

class Player : ContainerEnt {
  ActiveSkill[] skills;

  this(int x, int y, Container parent) {
    super(x, y, parent);
    isBlocking = true;
    speed = 50;
    
    hp = Stat(200);
    sp = Stat(1000);
    hunger = Stat(Time.hours(24));  // 24 hours
    thirst = Stat(100);  // 6 hours
    
    maxSize = 100;
    tags.isWalking = true;
  }

  Sym sym() {
    return Sym('@', Col.BLUE);
  }

  Update update(World world) {
    return null;
  }
  
  Update.Ret statUpdate(World world) {
    if (hunger > 0)
      hunger--;
    if (thirst > 0 && world.time.pticks % 10000 == 0)
      thirst--;
    return Update.Ret();
  }
  
  string name() { return "you"; }
}

class Grass : Ent {
  this(int x, int y, Container parent) {
    super(x, y, parent);
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
  this(int x, int y, Container parent) {
    super(x, y, parent);
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

  Sym sym() const {
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
  
  Ent contains() const {
    switch (type) {
      case Type.WATER:
        return new Water(-1, -1, new VoidContainer(), 1000);
        break;
      default:
        return null;
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
  n.timeout(10);
  n.curs_set(false);
  initColor();
  
  auto world = genWorld(7, 7);
  
  for (int i = 0; i < 2; i++) {
    while (true) {
      int x = uniform(0, world.stat.w),
          y = uniform(0, world.stat.h);
      if (!world.blockAt(x, y)) {
        world.movingEnts ~= new Deer(x, y, world.movingEnts);
        break;
      }
    }
  }
  
  for (int u = 0; u < Time.minutes(30); u++) {
    world.update();
  }
  
  while (true) {
    int x = uniform(-100, 100),
        y = uniform(-100, 100);
    int mx = world.stat.w / 2,
        my = world.stat.h / 2;
    if (!world.blockAt(x, y)) {
      world.player = new Player(mx + x, my + y, world.movingEnts);
      break;
    }
  }
  
  world.player.skills ~= new Jump();
  
  world.movingEnts ~= world.player;
  
  world.barMsg("One thousand deer");
  world.barMsg("roam this random spread.");
  world.barMsg("Now run around like an idiot");
  world.barMsg("and explore!");
  
  auto menu = new Menu(world);
  auto ms = new MainScreen(world, menu);
  menu.stack ~= ms;
  ms.init(menu);
  
  assert(ms.ui !is null);
  assert(menu.stack[$-1].ui !is null);
  
  while (menu.stack.length > 0) menu.update();
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
    n.init_pair(Col.YELLOW_BBG, n.COLOR_BLACK, n.COLOR_YELLOW);
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

abstract class Update {
  int timeReq;

  this(int timeReq) {
    this.timeReq = timeReq;
  }
  
  Ret update(World);
  
  static struct Ret {
    bool keep = true;
    Ent[] add;
    Update next;
  }
}

Update mkUpdate(int timeReq, Update.Ret delegate(World) upd) {
  class Upd : Update {
    this(int timeReq) {
      super(timeReq);
    }
  
    Update.Ret update(World world) {
      if (upd !is null)
        return upd(world);
      else
        return Update.Ret();
    }
  }
  
  return new Upd(timeReq);
}
Update mkUpdate(int timeReq, void delegate(World) upd) {
  Update.Ret f2(World world) {
    if (upd !is null)
      upd(world);
    return Update.Ret();
  }
  return mkUpdate(timeReq, &f2);
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
  
  static int days(int days) {
    return days * 24 * 60 * 60 * 100;
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

abstract class ActiveSkill {
  string name;
  Stat level;

  Menu.Mode use();
}

class Jump : ActiveSkill {
  this() {
    name = "Jump";
    level = Stat(0, 10);
  }
  
  Menu.Mode use() {
    return new Use();
  }
  
  class Use : Menu.Mode {
    TakeDest dest;
  
    this() {
      name = "Jump";
      key = 'j';
      dest = new TakeDest();
    }
    
    void init(Menu menu) {
      getKeys = true;
      dest.reset();
      dest.init(menu);
    }
    
    void preUpdate(Menu menu) {
      dest.preUpdate(menu);
    }
    
    Menu.Mode.Return update(char key, Menu menu) {
      static class Upd : Update {
        Coord dest;
        int time;
        
        this(Coord dest, int time) {
          this.dest = dest;
          this.time = time;
          super(time);
        }
        
        Update.Ret update(World world) {
          int mx, my;
          mx = compare(dest.x, world.player.x);
          my = compare(dest.y, world.player.y);
          world.player.x += mx;
          world.player.y += my;
          
          if (world.player.x == dest.x && world.player.y == dest.y) {
            return Update.Ret();
          } else {
            return Update.Ret(true, [], new Upd(dest, time));
          }
        }
      }
      
      dest.update(key, menu);
      if (dest.success) {
        menu.world.player.upd = new Upd(dest.cont, 10);
        menu.updateWorld();
        return Menu.Mode.Return();
      }
      return Menu.Mode.Return(true);
    }
  }
}

abstract class Take(A) : Menu.Mode {
  A cont;
  bool success;
  
  void reset() {
    success = false;
  }
}

class TakeDest : Take!Coord {
  bool setToPlayer;
  
  this() {
    name = "Choose destination";
    setToPlayer = true;
  }
  this(Coord start) {
    this();
    setToPlayer = false;
    cont = start;
  }
  
  void init(Menu menu) {
    if (setToPlayer) {
      cont = Coord(menu.world.player.x, menu.world.player.y);
    }    
  }
  
  void preUpdate(Menu menu) {
    menu.world.disp ~= Disp(Sym('X', Col.YELLOW), cont);
  }
  
  Menu.Mode.Return update(char key, Menu menu) {
    if (key == '\n') {
      success = true;
      return Menu.Mode.Return(false);
    }
  
    cont.add(getDirKey(key));
    
    return Menu.Mode.Return(true);
  }
}

struct Disp {
  Sym sym;
  Coord coord;
}

struct Tags {
  uint size; // 1 is stick, 10 is rock, 100 is whole deer carcass
  // Coefficients multiplied by size for final value
  float drinkCo = 0, // 0 for no, otherwise how much it refilled
        eatCo = 0, // same as drink
        weightCo = 0; // (lbs.) final weight of 1 is stick, 5 is rock, 120 is deer carcass
  bool isFluid,
       isSplittable, // can be split into smaller chunks
       isWalking; // walks on the ground, leaves tracks...
       
  int drink() const { return cast(int) (size * drinkCo); }
  int eat() const { return cast(int) (size * eatCo); }
  int weight() const { return cast(int) (size * weightCo); }
}

interface Container {
  enum AddRet {
    NO_ROOM,
    WRONG_TYPE,
    SUCCESS
  }
  
  Ent[] inside();
  bool remove(Ent);
  AddRet add(Ent);
}

abstract class ContainerEnt : Ent, Container {
  Ent[] contents;
  uint maxSize;
  bool isWatertight;
  
  this(int x, int y, Container parent) {
    super(x, y, parent);
  }
  
  int spaceLeft() const {
    int space = maxSize;
    foreach (e; contents) {
      space -= e.size;
    }
    return space;
  }
  
  Ent[] inside() {
    return contents;
  }
  bool remove(Ent e) {
    contents.remove(e);
    return true;
  }
  Container.AddRet add(Ent e) {
    if (e.isFluid && !isWatertight) {
      return Container.AddRet.WRONG_TYPE;
    }
    if (e.size > spaceLeft) {
      return Container.AddRet.NO_ROOM;
    }
    contents ~= e;
    return Container.AddRet.SUCCESS;
  }
}

class Water : Ent {
  this(int x, int y, Container parent, uint size) {
    super(x, y, parent);
    this.tags.size = size;
    this.tags.drinkCo = 5;
    this.tags.weightCo = 2;
    this.tags.isFluid = true;
  }
  
  string name() { return "water"; }
  Sym sym() { return Sym('~', Col.BLUE); }
}

class ContainerList : Container {
  Ent[] list;
  alias list this;
  
  Ent[] inside() {
    return list;
  }
  Container.AddRet add(Ent e) {
    list ~= e;
    return Container.AddRet.SUCCESS;
  }
  bool remove(Ent e) {
    list.remove(e);
    return true;
  }
}

class VoidContainer : Container {
  Ent[] inside() {
    return [];
  }
  Container.AddRet add(Ent e) {
    return Container.AddRet.SUCCESS;
  }
  bool remove(Ent e) {
    return true;
  }
}

struct Tracks {
  uint start;
  Ent source;
  Dir dir;
  uint num;
  
  static const maxAge = Time.days(1);
  static const sym = Sym('"', Col.YELLOW_BBG);
}

Dir coordToDir(Coord c) {
  assert(c.x != 0 || c.y != 0);
  
  if (c == Coord(0, -1)) {
    return Dir.N;
  } else if (c == Coord(1, -1)) {
    return Dir.NE;
  } else if (c == Coord(1, 0)) {
    return Dir.E;
  } else if (c == Coord(1, 1)) {
    return Dir.SE;
  } else if (c == Coord(0, 1)) {
    return Dir.S;
  } else if (c == Coord(-1, 1)) {
    return Dir.SW;
  } else if (c == Coord(-1, 0)) {
    return Dir.W;
  } else if (c == Coord(-1, -1)) {
    return Dir.NW;
  } else {
    assert(false);
  }
}