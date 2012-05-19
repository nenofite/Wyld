module wyld.main;

import wyld.format;

import core.thread: Thread, dur;
import n = ncs.curses;
import std.string: toStringz;
import std.random: uniform;

const int viewHeight = 20,
          viewWidth = 20;
          
string[] msgs;

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
  int w, h;
  //int px, py;
  Ent player;
  Ent[] ents;
  Grid!(Terr) terr;

  this(int w, int h) {
    this.w = w;
    this.h = h;
  
    this.terr = new Grid!(Terr)(w, h);
  }
  
  void draw(int by, int bx) {
    int cx = player.x - (viewWidth / 2),
        cy = player.y - (viewHeight / 2);
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

    //Sym('@', Col.BLUE).draw(player.y + by - cy, player.x + bx - cx);

    //clearLine(n.LINES - 2);
    clearLine(n.LINES - 1);
    n.attrset(n.COLOR_PAIR(Col.TEXT));
    n.mvprintw(n.LINES - 1, 2, "%d, %d  ", player.x, player.y);
    n.attrset(n.COLOR_PAIR(Col.GREEN));
    n.printw("%d, %d", cx, cy);
    n.attrset(n.COLOR_PAIR(Col.TEXT));
    n.printw("  -  ND: %d", notDrawn);
    //n.printw("  Deer@%d, %d", ents[0].x, ents[0].y);
  }

  bool inView(int x, int y) {
    x -= player.x - (viewWidth / 2);
    y -= player.y - (viewHeight / 2);
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
    if (!terr.inside(x, y)) return true;
    foreach (e; entsAt(x, y)) {
      if (e.isBlocking) return true;
    }
    if (terr.get(x, y).isBlocking) return true;
    return false;
  }

  int moveCostAt(int x, int y) {
    int cost = terr.get(x, y).moveCost();
    foreach (e; entsAt(x, y)) {
      cost += e.moveCost;
    }
    return cost;
  }

  //void movePlayer(int nx, int ny) {
  //  if (!blockAt(nx, ny)) {
  //    player.x = nx;
  //    player.y = ny;
  //  }
  //}
  //void movePlayerD(int nx, int ny) {
  //  movePlayer(player.x + nx, player.y + ny);
  //}

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

  void playerUpdate(Update upd) {
    while (!upd.run(this)) {
      update();
    }
  }
}

abstract class Ent {
  int x, y;
  bool isBlocking;
  int moveCost;

  Update upd;

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

  Update move(int dx, int dy, World w) {
    int nx = x + dx,
        ny = y + dy;
    if (w.terr.inside(nx, ny)) {
      int cost = w.moveCostAt(x, y) 
               + w.moveCostAt(nx, ny)
               + moveCost;
      return new Update(cost, (World w) {
        if (!w.blockAt(nx, ny)) {
          x = nx;
          y = ny;
        } else
          barMsg("Blocked.");
      });
    }
    return new Update(0, null);
  }
}

class Deer : Ent {
  int destX, destY;
  bool hasDest;

  this(int x, int y) {
    super(x, y);
    isBlocking = true;
    moveCost = 150;
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
      return move(mx, my, world);
      //return new Update(100, (World w) {
      //  collMoveD(mx, my, world);
      //});
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

class Troll : Deer {
  this(int x, int y) {
    super(x, y);
    moveCost = 500;
  }
  
  Sym sym() {
    return Sym('&', Col.GREEN);
  }
}

class Player : Ent {
  this(int x, int y) {
    super(x, y);
    isBlocking = true;
    moveCost = 50;
  }

  Sym sym() {
    return Sym('@', Col.BLUE);
  }

  Update update(World world) {
    //return Update.empty();
    return null;
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
    MUD,
    ROCK,
    WATER
  }

  Type type;

  Sym sym() {
    switch (type) {
      case Type.DIRT:
        return Sym('#', Col.YELLOW);
        break;
      case Type.MUD:
        return Sym('~', Col.YELLOW);
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
  world.player = new Player(5, 11);
  world.ents ~= world.player;

  world.ents ~= new Deer(10, 6);
  world.ents ~= new Deer(11, 7);
  world.ents ~= new Deer(12, 6);
  world.ents ~= new Deer(13, 9);
  world.ents ~= new Troll(15, 2);
  
  /+barMsg("I");
  barMsg("do");
  barMsg("love");
  barMsg("a");
  barMsg("good");
  barMsg("pie.");+/
  
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
  world.draw(0, 0);

  int badKey = -1;

  bool cont = true;
  while (cont) {
    int key = n.getch();
    switch (key) {
      //case n.KEY_UP:
      case '8':
        //world.playerUpdate(world.player.move(0, -1, world));
        world.player.upd = world.player.move(0, -1, world);
        break;
      //case n.KEY_DOWN:
      case '2':
        //world.playerUpdate(world.player.move(0, 1, world));
        world.player.upd = world.player.move(0, 1, world);
        break;
      //case n.KEY_LEFT:
      case '4':
        //world.playerUpdate(world.player.move(-1, 0, world));
        world.player.upd = world.player.move(-1, 0, world);
        break;
      //case n.KEY_RIGHT:
      case '6':
        //world.playerUpdate(world.player.move(1, 0, world));
        world.player.upd = world.player.move(1, 0, world);
        break;
      //case n.KEY_HOME:
      case '7':
        //world.playerUpdate(world.player.move(-1, -1, world));
        world.player.upd = world.player.move(-1, -1, world);
        break;
      //case n.KEY_PPAGE:
      case '9':
        //world.playerUpdate(world.player.move(1, -1, world));
        world.player.upd = world.player.move(1, -1, world);
        break;
      //case n.KEY_B2:
      case '5':
        world.player.upd = new Update(100, null);
        break;
      //case n.KEY_END:
      case '1':
        //world.playerUpdate(world.player.move(-1, 1, world));
        world.player.upd = world.player.move(-1, 1, world);
        break;
      //case n.KEY_NPAGE:
      case '3':
        //world.playerUpdate(world.player.move(1, 1, world));
        world.player.upd = world.player.move(1, 1, world);
        break;
      case 'Q':
        cont = false;
        break;
      case n.KEY_RESIZE:
        clearScreen();
        break;
      case 'a':
        world.terr.modify(world.player.x, world.player.y, (Terr a) { a.type = Terr.Type.MUD; return a; });
        break;
      default:
        badKey = key;
        break;
    }
    
    n.attrset(n.COLOR_PAIR(Col.TEXT));
    clearScreen();
    while (world.player.upd !is null) {
      world.update();
      world.draw(0, 0);
      n.refresh();
      Thread.sleep(dur!("nsecs")(500));
      //n.getch();
    }

    if (badKey != -1) { 
      barMsg(format("Unknown key: %d '%s'", badKey, cast(char) badKey));
    }
    badKey = -1;
    
    showBarMsgs();
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



//void barMsg(A...)(const string msg, A fmt) {
//  msgs ~= format(msg, fmt);
void barMsg(string msg) {
  msgs ~= msg;

  /*n.attrset(n.COLOR_PAIR(Col.BORDER));
  clearLine(n.LINES - 2);
  n.mvprintw(n.LINES - 2, 0, toStringz(msg), fmt);*/
}

void showBarMsgs() {
  int dispLen = cast(int) msgs.length;
  if (dispLen > 5) dispLen = 5;

  n.attrset(n.COLOR_PAIR(Col.BORDER));
  int offset;
  while (true) {
    int ln = n.LINES - dispLen;
    for (int i = 0; i < dispLen; i++) {
      clearLine(ln);
      n.mvprintw(ln, 0, toStringz(msgs[i + offset]));
      ln++;
    }
    if (offset + dispLen < msgs.length) {
      clearLine(n.LINES - 1);
      n.mvprintw(n.LINES - 1, 0, toStringz("-- [Enter] for more --"));
      while (n.getch() != '\n') {}
      offset++;
    } else {
      break;
    }
  }
  


  /+int ln = n.LINES - (cast(int) msgs.length);
  n.attrset(n.COLOR_PAIR(Col.BORDER));
  foreach (m; msgs) {
    clearLine(ln);
    n.mvprintw(ln, 0, toStringz(m));
    ln++;
  }+/
  msgs = [];



  /+
  int m = 0;
  while (true) {
//    msgs.length - m
    

    for (int i = (cast(int) msgs.length) - m; i >= 0; i--) {
      int line = (cast(int) n.LINES) - 2 - i;
      clearLine(line);
      n.mvprintw(line, 0, toStringz(msgs[$ - 1 - i]));
    }
    clearLine(n.LINES - 1);
    n.mvprintw(n.LINES - 1, 0, "[Enter] for more");
    while (n.getch() != '\n') {}
    m++;
    if (m >= msgs.length) break;
  }

  /+
  int n = 0;
  for (int i = 0; i < 4; i++) {
    clearLine(n.LINES - i - 1);
    n.mvprintw(n.LINES - i - 1, 0, toStringz(msgs[n + i]));
  }


  int line, i;
  bool more;
  
  while (i < msgs.length) {
    line = cast(int) msgs.length;
    if (line > 5) line = 5;
    n.attrset(n.COLOR_PAIR(Col.BORDER));
    
    more = msgs.length > 5;
    if (more) {
      clearLine(n.LINES - 1);
      n.mvprintw(n.LINES - 1, 0, toStringz("[Enter] for more"));
    }
    
    //n.attrset(n.COLOR_PAIR(Col.BORDER));
    while (line >= 0) {
      clearLine(n.LINES - line - 1);
      n.mvprintw(n.LINES - line - 1, 0, toStringz(msgs[i]));
      i++;
      line--;
      if (more && line < 1) break;
    }
    
    while (n.getch() != '\n') {}
  }
  
  msgs = [];+/+/
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

  static Update empty() {
    return new Update(0, null);
  }
}
