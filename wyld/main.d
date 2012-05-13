module wyld.main;

import n = ncs.curses;
import std.string: toStringz;
import std.random: uniform;

const int viewHeight = 20,
          viewWidth = 20;

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
  int px, py;
  int w, h;
  Ent[] ents;
  Grid!(Terr) terr;

  this(int w, int h) {
    this.w = w;
    this.h = h;
  
    this.terr = new Grid!(Terr)(w, h);
  }
  
  void draw(int by, int bx) {
    int cx = px - (viewWidth / 2),
        cy = py - (viewHeight / 2);
    Sym s;
    int notDrawn;

    for (int y = 0; y < viewHeight; y++) {
      n.move(y + by, bx);
      for (int x = 0; x < viewWidth; x++) {
        s = baseAt(cx + x, cy + y);
        n.attrset(n.COLOR_PAIR(s.color));
        n.addch(s.ch);
      }
    }

    foreach (e; ents) {
      if (inView(e.x, e.y)) {
	e.sym().draw(e.y + by - cy, e.x + bx - cx);
      } else {
	notDrawn++;
      }
    }

    Sym('@', Col.BLUE).draw(py + by - cy, px + bx - cx);

    clearLine(n.LINES - 2);
    clearLine(n.LINES - 1);
    n.attrset(n.COLOR_PAIR(Col.TEXT));
    n.mvprintw(n.LINES - 1, 2, "%d, %d  ", px, py);
    n.attrset(n.COLOR_PAIR(Col.GREEN));
    n.printw("%d, %d", cx, cy);
    n.attrset(n.COLOR_PAIR(Col.TEXT));
    n.printw("  -  ND: %d", notDrawn);
    //n.printw("  Deer@%d, %d", ents[0].x, ents[0].y);
    auto d = cast (Deer) ents[0];
    n.printw("  -  dest %d, %d  %d, %d", d.destX, d.destY, d.x, d.y);
  }

  bool inView(int x, int y) {
    x -= px - (viewWidth / 2);
    y -= py - (viewHeight / 2);
    return (x >= 0 && x < viewWidth && y >= 0 && y < viewHeight); 
  }
  
  Sym baseAt(int x, int y) {
    //if (px == x && py == y) {
    //  return Sym('@', Col.BLUE);
    //}

    //auto es = entsAt(x, y);
    //if (es.length > 0)
    //  return es[0].sym();

    if (terr.inside(x, y))  
      return terr.get(x, y).sym();

    if (x % 3 == 0)
      return Sym('\'', Col.GREEN);
    if (y % 3 == 0)
      return Sym('-', Col.GREEN);
    return Sym(' ', Col.GREEN);
  }

  Ent[] entsAt(int x, int y) {
    //if (x in ents) {
    //  auto xd = ents[x];
    //  if (y in xd) {
    //    return xd[y];
    //  }
    //}
    //return [];

    Ent[] ret;
    foreach (e; ents) {
      if (e.x == x && e.y == y) ret ~= e;
    }
    return ret;
  }

  bool blockAt(int x, int y) {
    foreach (e; entsAt(x, y)) {
      if (e.isBlocking) return true;
    }
    if (!terr.inside(x, y)) return true;
    if (terr.get(x, y).isBlocking) return true;
    return false;
  }

  void movePlayer(int nx, int ny) {
    if (!blockAt(nx, ny)) {
      px = nx;
      py = ny;
    }
  }
  void movePlayerD(int nx, int ny) {
    movePlayer(px + nx, py + ny);
  }

  //void collMove(int ox, int oy, Ent ent, int nx, int ny) {
  //  if (!blockAt(nx, ny)) {
  //    //ents[ox][oy].remove(ent);
  //    //ents[nx][ny] ~= ent;
  //    ent.x = nx;
  //    ent.y = ny;
  //    //TODO clean this up
  //  }
  //}
  //void collMoveD(int ox, int oy, Ent ent, int nx, int ny) {
  //  collMove(ox, oy, ent, nx + ox, ny + oy);
  //}

  void update() {
    //foreach (x, col; ents) {
    //  foreach (y, stack; col) {
    //    foreach (e; stack)
    //      e.update(x, y, this);
    //  }
    //}
  
    foreach (e; ents) {
      e.runUpdate(this);
      //e.getUpdate(this).run(this);
      //e.update(e.x, e.y, this).run(this);
      //TODO clean this up
    }
  }
}

abstract class Ent {
  int x, y;
  bool isBlocking;

  private Update upd;

  this(int x, int y) {
    this.x = x;
    this.y = y;
  }

  Sym sym();
  //void update(int x, int y, World);
  Update update(World);

  //Update getUpdate(World w) {
  //  if (upd is null)
  //    upd = update(w);
  //  return upd;
  //}
  void runUpdate(World w) {
    if (upd is null) {
      upd = update(w);
    }
    if (upd.run(w)) {
      upd = null;
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
}

class Deer : Ent {
  int destX, destY;
  bool hasDest;

  this(int x, int y) {
    super(x, y);
    isBlocking = true;
  }

  Sym sym() {
    return Sym('D', Col.WHITE);
  }

  Update update(World world) {
    if (x == destX && y == destY) {
      hasDest = false;
    }
    if (hasDest) {
      int mx, my;
      mx = compare(destX, x);
      my = compare(destY, y);
      return new Update(100, (World w) {
        collMoveD(mx, my, world);
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
}

class Tree : Ent {
  this(int x, int y) {
    super(x, y);
    isBlocking = true;
  }

  Sym sym() {
    return Sym('t', Col.GREEN);
  }

  Update update(World world) {
    return new Update(100, (World w) {
      int rand = uniform!("[]")(0, 100);
      if (rand == 0) {
        world.ents.remove(this);
      }
    });
  }
}

struct Terr {
  enum Type {
    DIRT,
    ROCK,
    WATER
  }

  Type type;

  Sym sym() {
    switch (type) {
      case Type.DIRT:
        return Sym('#', Col.YELLOW);
        break;
      case Type.ROCK:
        return Sym('#', Col.WHITE);
        break;
      case Type.WATER:
        return Sym('~', Col.BLUE);
        break;
      default:
        throw new Error("Unknown Terr type.");
        break;
    }
  }

  bool isBlocking() {
    switch (type) {
      case Type.WATER:
	return true;
	break;
      default:
	return false;
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

  private int conv(int x, int y) {
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

  bool inside(int x, int y) {
    return (x >= 0 && x < w && y >= 0 && y < h);
  }
}

void main() {
  //auto bob = [1, 2, 3];
  //bob.remove(1);
  //bob.remove(3);
  //assert(bob.length == 1);

  n.initscr();
  scope (exit) n.endwin();
  n.cbreak();
  n.noecho();
  n.keypad(n.stdscr, false);
  n.curs_set(false);
  initColor();
  
  auto world = new World(20, 20);
  world.px = 5;
  world.py = 11;

  world.ents ~= new Deer(10, 6);
  world.ents ~= new Deer(11, 7);
  world.ents ~= new Deer(12, 6);
  world.ents ~= new Deer(13, 9);
  //for (int x = 0; x < 15; x++) {
  //  world.ents ~= new Deer(4 + x, 11);
  //  world.ents ~= new Deer(4 + x, 12);
  //  world.ents ~= new Deer(4 + x, 13);
  //  world.ents ~= new Deer(4 + x, 14);
  //}

//  for (int x = 0; x < 10000; x++) {
//    for (int y = 0; y < 10; y++)
//      world.ents[x][y] ~= new Deer();
//  }

//  world.entsAt(2, 29);
 
  //bool badKey = false;
  int badKey = -1;
 
  bool cont = true;
  while (cont) {
    world.draw(0, 0);
    
    if (badKey != -1) { 
//      n.attrset(n.COLOR_PAIR(Col.RED));
//      n.mvprintw(n.LINES - 1, n.COLS - 2, "??");
      barMsg("Unknown key: %d '%c'", badKey, badKey);
    }
    badKey = -1;

    n.refresh();

    for (int x = 0; x < 100; x++)
      world.update();
    
    int key = n.getch();
    switch (key) {
      //case n.KEY_UP:
      case '8':
        world.movePlayerD(0, -1);
        break;
      //case n.KEY_DOWN:
      case '2':
        world.movePlayerD(0, 1);
        break;
      //case n.KEY_LEFT:
      case '4':
        world.movePlayerD(-1, 0);
        break;
      //case n.KEY_RIGHT:
      case '6':
        world.movePlayerD(1, 0);
        break;
      //case n.KEY_HOME:
      case '7':
	world.movePlayerD(-1, -1);
	break;
      //case n.KEY_PPAGE:
      case '9':
	world.movePlayerD(1, -1);
	break;
      //case n.KEY_B2:
      case '5':
	break;
      //case n.KEY_END:
      case '1':
	world.movePlayerD(-1, 1);
	break;
      //case n.KEY_NPAGE:
      case '3':
	world.movePlayerD(1, 1);
	break;
      case 'Q':
        cont = false;
        break;
      case n.KEY_RESIZE:
        clearScreen();
        break;
      case 'a':
        //world.terr.set(world.px, world.py, world.terr.get(world.px, world.py))
        //world.terr[world.px][world.py].type = Terr.Type.WATER;
        world.terr.modify(world.px, world.py, (Terr a) { a.type = Terr.Type.WATER; return a; });
//        switch (n.getch()) {
//          case n.KEY_UP:
//            break;
//          case n.KEY_DOWN:
//            break;
//          case n.KEY_LEFT:
//            break;
//          case n.KEY_RIGHT:
//            break;
//        }
        break;
      default:
        badKey = key;
        break;
    }
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

void barMsg(A...)(const string msg, A fmt) {
  n.attrset(n.COLOR_PAIR(Col.BORDER));
  clearLine(n.LINES - 2);
  //n.mvprintw(n.LINES - 1, 0, "  %s  ", toStringz(msg));
  n.mvprintw(n.LINES - 2, 0, toStringz(msg), fmt);
}

void remove(A)(ref A[] ls, A elem) {
  A[] ret;
  foreach (a; ls) {
    if (a != elem) ret ~= a;
  }
  ls = ret;
}

/+void remove(A)(ref A[] ls, A elem) {
  A[] ret;
  ret.length = ls.length - 1;
  bool started;
  for (int i = 0; i < ls.length - 1; i++) {
    if (ls[i] == elem) {
      started = true;
    }
    ret[i] = ls[started ? i + 1 : i];
  }
/+
  int start = -1;
  foreach (i, a; ls) {
    if (a == elem) {
      start = cast (int) i;
      break;
    } else {
      ret[i] = a;
    }
  }
  for (int i = start; i < ls.length - 1; i++) {
    ls[i] = ls[i + 1];
  }
  //ls.length = ls.length - 1;
+/
  ls = ret;
}
+/

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
