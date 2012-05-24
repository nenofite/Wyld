module wyld.main;

import wyld.format;
import wyld.layout;
import wyld.worldgen;

import core.thread: Thread, dur;
import n = ncs.curses;
import std.string: toStringz;
import std.random: uniform;

const int viewHeight = 25,
          viewWidth = 25;
          
enum Col {
  TEXT,
  BORDER,
  BLUE,
  GREEN,
  RED,
  YELLOW,
  WHITE
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
  string[] msgs;
  
  struct StatCont {
    Terr terr;
    Ent[] statEnts;
  }

  this() {}

  this(int w, int h) {
    stat = new Grid!(StatCont)(w, h);
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
    }
  }

  void playerUpdate(Update upd) {
    while (!upd.run(this)) {
      update();
    }
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
  }

  Sym sym() {
    return Sym('@', Col.BLUE);
  }

  Update update(World world) {
    return null;
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
        return Sym('~', Col.YELLOW);
        break;
      case Type.ROCK:
        return Sym(pocked ? '-' : '.', Col.WHITE);
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
  A[] ls;
  int w, h;

  this(int w, int h) {
    this.w = w;
    this.h = h;
    ls.length = w * h;
  }

  private int conv(int x, int y) const {
    if (!inside(x, y)) throw new Error("Not in bounds of Grid.");
    return x * w + y;
  }

  A get(int x, int y) {
    return ls[conv(x, y)];
  }
  void set(int x, int y, A a) {
    ls[conv(x, y)] = a;
  }
  void modify(int x, int y, A delegate(A) f) {
    auto a = get(x, y);
    set(x, y, f(a));
  }

  void map(A delegate(A) f) {
    foreach (i, a; ls) {
      ls[i] = f(a);
    }
  }
  Grid!(B) mapT(B)(B delegate(A) f) {
    auto ret = new Grid!(B)(w, h);
    foreach (i, a; ls) {
      ret.ls[i] = f(a);
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
  
  n.attrset(n.COLOR_PAIR(Col.GREEN));
  n.mvprintw(2, 2, "Generating world...");
  n.refresh();

  auto world = genWorld(40, 40);
  world.player = new Player(5, 11);
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
  
  auto hud = mainView(world);
  
  hud.draw(Box.Dim(0, 0, n.COLS, n.LINES));

  bool cont = true;
  while (cont) {
    int key = n.getch();
    n.flushinp();
    switch (key) {
      //case n.KEY_UP:
      case '8':
        world.player.upd = world.player.move(0, -1, world);
        break;
      //case n.KEY_DOWN:
      case '2':
        world.player.upd = world.player.move(0, 1, world);
        break;
      //case n.KEY_LEFT:
      case '4':
        world.player.upd = world.player.move(-1, 0, world);
        break;
      //case n.KEY_RIGHT:
      case '6':
        world.player.upd = world.player.move(1, 0, world);
        break;
      //case n.KEY_HOME:
      case '7':
        world.player.upd = world.player.move(-1, -1, world);
        break;
      //case n.KEY_PPAGE:
      case '9':
        world.player.upd = world.player.move(1, -1, world);
        break;
      //case n.KEY_B2:
      case '5':
        world.player.upd = new Update(100, null);
        break;
      //case n.KEY_END:
      case '1':
        world.player.upd = world.player.move(-1, 1, world);
        break;
      //case n.KEY_NPAGE:
      case '3':
        world.player.upd = world.player.move(1, 1, world);
        break;
      case 'Q':
        cont = false;
        break;
      case n.KEY_RESIZE:
        clearScreen();
        break;
      default:
        world.barMsg(format("Unknown key: %d '%s'", key, cast(char) key));
        break;
    }
    
    n.attrset(n.COLOR_PAIR(Col.TEXT));
    clearScreen();
    hud.draw(Box.Dim(0, 0, n.COLS, n.LINES));
    while (world.player.upd !is null) {
      world.update();
      hud.draw(Box.Dim(0, 0, n.COLS, n.LINES));
      n.refresh();
      Thread.sleep(dur!("nsecs")(500));
    }
    
    n.refresh();
  }
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
