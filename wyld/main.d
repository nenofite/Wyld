module wyld.main;

import n = ncs.curses;

/*const*/ int viewHeight = 20,
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
}

class World {
  int px, py;
  int w, h;
  Ent[][int][int] ents;
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

    for (int y = 0; y < viewHeight; y++) {
      n.move(y + by, bx);
      for (int x = 0; x < viewWidth; x++) {
        s = at(cx + x, cy + y);
        n.attrset(n.COLOR_PAIR(s.color));
        n.addch(s.ch);
      }
    }

    clearLine(n.LINES - 1);
    n.attrset(n.COLOR_PAIR(Col.TEXT));
    n.mvprintw(n.LINES - 1, 2, "%d, %d  ", px, py);
    n.attrset(n.COLOR_PAIR(Col.GREEN));
    n.printw("%d, %d", cx, cy);
  }
  
  Sym at(int x, int y) {
    if (px == x && py == y) {
      return Sym('@', Col.BLUE);
    }
    if (x in ents) {
      if (y in ents[x])
        return ents[x][y][0].sym();
    }

    if (terr.inside(x, y))  
      return terr.get(x, y).sym();

    if (x % 3 == 0)
      return Sym('\'', Col.GREEN);
    if (y % 3 == 0)
      return Sym('-', Col.GREEN);
    return Sym(' ', Col.GREEN);
  }

  Ent[] entsAt(int x, int y) {
    if (x in ents) {
      auto xd = ents[x];
      if (y in xd) {
        return xd[y];
      }
    }
    return [];
  }

  bool blockAt(int x, int y) {
    foreach (e; entsAt(x, y)) {
      if (e.isBlocking) return true;
    }
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
}

abstract class Ent {
  bool isBlocking;

  Sym sym();
}

class Deer : Ent {
  this() {
    isBlocking = true;
  }

  Sym sym() {
    return Sym('D', Col.TEXT);
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
    if (!inside(x, y)) throw new Error("Not in bounds of Grid!");
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
  n.initscr();
  scope (exit) n.endwin();
  n.cbreak();
  n.noecho();
  n.keypad(n.stdscr, true);
  n.curs_set(false);
  initColor();
  
  auto world = new World(20, 20);
  world.px = 5;
  world.py = 11;

//  for (int x = 0; x < 10000; x++) {
//    for (int y = 0; y < 10; y++)
//      world.ents[x][y] ~= new Deer();
//  }

  world.entsAt(2, 29);
 
  bool badKey = false;
 
  bool cont = true;
  while (cont) {
    world.draw(0, 0);
    
    if (badKey) { 
      n.attrset(n.COLOR_PAIR(Col.RED));
      n.mvaddch(n.LINES - 1, n.COLS - 1, '?');
    }
    badKey = false;

    n.refresh();
    
    switch (n.getch()) {
      case n.KEY_UP:
        world.movePlayerD(0, -1);
        break;
      case n.KEY_DOWN:
        world.movePlayerD(0, 1);
        break;
      case n.KEY_LEFT:
        world.movePlayerD(-1, 0);
        break;
      case n.KEY_RIGHT:
        world.movePlayerD(1, 0);
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
        badKey = true;
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
