module wyld.layout;

import wyld.main;

import std.algorithm: reduce, map, max;
import std.string: toStringz;

abstract class Box {
  int w() const { return 0; }
  int h() const { return 0; }

  void draw(Dim);
  
  struct Dim {
    int x, y, w, h;
    
    int x2() const {
      return x + w - 1;
    }
    int y2() const {
      return y + h - 1;
    }
    
    void rotate() {
      auto ox = x,
           ow = w;
      x = y;
      w = h;
      y = ox;
      h = ow;
    }
  }
}

abstract class Container : Box {
  bool addChild(Box);
  bool removeChild(Box);
}

class List : Container {
  bool horiz, rtl;
  Box[] children;
  
  bool addChild(Box b) {
    children ~= b;
    return true;
  }
  
  bool removeChild(Box b) {
    //TODO implement this
    throw new Error("Remove not implemented.");
  }
  
  void draw(Dim dim) {
    if (horiz) {
      int x = rtl ? dim.x2() + 1 : dim.x;
      for (int i = 0; i < children.length - 1; i++) {
        auto b = children[i];
        if (rtl) x -= b.w;
        b.draw(Dim(x, dim.y, b.w, dim.h));
        if (!rtl) x += b.w;
      }
      int width = (rtl ? x - dim.x : dim.x2() - x + 1);
      if (rtl) x = dim.x;
      children[$-1].draw(Dim(x, dim.y, width, dim.h));
    } else {
      int y = rtl ? dim.y2() + 1 : dim.y;
      for (int i = 0; i < children.length - 1; i++) {
        auto b = children[i];
        if (rtl) y -= b.h;
        b.draw(Dim(dim.x, y, dim.w, b.h));
        if (!rtl) y += b.h;
      }
      int height = (rtl ? y - dim.y : dim.y2() - y + 1);
      if (rtl) y = dim.y;
      children[$-1].draw(Dim(dim.x, y, dim.w, height));
    }
  }
  
  int w() const {
    if (horiz) {
      return reduce!("a + b")(map!("a.w")(children));
    } else {
      return reduce!(max)(map!("a.w")(children));
    }
  }
  
  int h() const {
    if (horiz) {
      return reduce!(max)(map!("a.h")(children));
    } else {
      return reduce!("a + b")(map!("a.h")(children));
    }
  }
}


class WorldView : Box {
  World world;

  this(World world) {
    this.world = world;
  }
  
  int w() const { return viewWidth; }
  int h() const { return viewHeight; }
  
  void draw(Dim dim) {
    int cx = world.player.x - (viewWidth / 2),
        cy = world.player.y - (viewHeight / 2);
    int bx = dim.x, by = dim.y;
    Sym s;
    int drawn;  // TODO can be removed?

    for (int y = 0; y < viewHeight; y++) {
      n.move(y + by, bx);
      for (int x = 0; x < viewWidth; x++) {
        s = world.baseAt(cx + x, cy + y);
        if (world.stat.inside(cx + x, cy + y)) {
          auto se = world.stat.get(cx + x, cy + y).statEnts;
          if (se.length > 0)
            s = se[$-1].sym();
        }
        n.attrset(n.COLOR_PAIR(s.color));
        n.addch(s.ch);
      }
    }

    foreach (e; world.movingEnts) {
      if (world.inView(e.x, e.y)) {
        e.sym().draw(e.y + by - cy, e.x + bx - cx);
        drawn++;
      }
    }
  }
}

class OnGround : Box {
  World world;
  
  this(World world) {
    this.world = world;
  }
  
  int h() const { return 6; }
  
  void draw(Dim dim) {
    string[] lines;
    foreach (e; world.entsAt(world.player.x, world.player.y)) {
      if (e !is world.player) {
        lines ~= e.name();
      }
    }
  
    n.attrset(n.COLOR_PAIR(Col.TEXT));
    n.attron(n.A_BOLD);
    n.mvprintw(dim.y, dim.x, "- On ground: -");
    n.attroff(n.A_BOLD);
    printBlock(dim.y + 1, dim.x, lines);
  }
}

void printBlock(int y, int x, string[] lines) {
  foreach (l; lines) {
    n.mvprintw(y, x, toStringz(l));
    y++;
  }
}

Box mainView(World world) {
  auto msgPane = new List();
  msgPane.rtl = true;
  msgPane.addChild(new Msgs(world));
  msgPane.addChild(new HBar(" - Messages -"));
  {
    auto menuPane = new List();
    msgPane.addChild(menuPane);
    menuPane.rtl = true;
    menuPane.horiz = true;
    menuPane.addChild(new Menu(world));
    menuPane.addChild(new VBar());
    {
      auto timeRow = new List();
      menuPane.addChild(timeRow);
      timeRow.addChild(new TimeBar(world));
      {
        auto cols = new List();
        timeRow.addChild(cols);
        cols.horiz = true;
        {
          auto rows = new List();
          cols.addChild(rows);
          rows.addChild(new WorldView(world));
          rows.addChild(new OnGround(world));
        }
        {
          auto rows = new List();
          cols.addChild(rows);
          rows.addChild(new Minimap(world));
          rows.addChild(new Nearby(world));
        }
        cols.addChild(new Stats(world));
      }
    }
  }
  
  return msgPane;
}

class Msgs : Box {
  World world;
  
  this(World world) {
    this.world = world;
  }
  
  int h() const { return 6; }
  
  void draw(Dim dim) {
    n.attrset(n.COLOR_PAIR(Col.TEXT));
    int msgIndex = max(0, cast(int) world.msgs.length - dim.h);
    
    for (int i = 0; i < dim.h; i++) {
      clearLine(dim.y + i);
      if (msgIndex < world.msgs.length) {
        n.mvprintw(dim.y + i, dim.x, toStringz(world.msgs[msgIndex]));
        msgIndex++;
      }
    }
  }
}

class Menu : Box {
  World world;
  
  this(World world) {
    this.world = world;
  }
  
  int w() const { return 20; }
  
  void draw(Dim dim) {
    n.mvprintw(dim.y, dim.x, "Menu go here!");
  }
}

class VBar : Box {
  int w() const { return 1; }
  
  void draw(Dim dim) {
    n.attrset(n.COLOR_PAIR(Col.BORDER));
    for (int y = dim.y; y <= dim.y2(); y++) {
      n.mvprintw(y, dim.x, " ");
    }
  }
}

class HBar : Box {
  string label;
  
  this(string label = "") {
    this.label = label;
  }

  int h() const { return 1; }
  
  void draw(Dim dim) {
    n.attrset(n.COLOR_PAIR(Col.BORDER));
    n.move(dim.y, dim.x);
    for (int x = 0; x <= dim.x2(); x++) {
      n.addch(' ');
    }
    n.attron(n.A_BOLD);
    n.mvprintw(dim.y, dim.x, toStringz(label));
    n.attroff(n.A_BOLD);
  }
}

class TimeBar : Box {
  World world;
  
  this(World world) {
    this.world = world;
  }
  
  int h() const { return 1; }
  
  void draw(Dim dim) {
    n.mvprintw(dim.y, dim.x, "Time bar!");
  }
}

class Minimap : Box {
  World world;
  
  const int mapW = 7,
            mapH = 7,
            padW = mapW / 2,
            padH = mapH / 2;
  
  int w() const { return mapW; }
  int h() const { return mapH; }
  
  this(World world) {
    this.world = world;
  }
  
  void draw(Dim dim) {
    n.mvprintw(dim.y, dim.x, "Minimap");
    
    for (int y = 0; y < h(); y++) {
      for (int x = 0; x < w(); x++) {
        int cx = world.xToGeo(world.player.x) - padW,
            cy = world.yToGeo(world.player.y) - padH;
        if (world.geos.inside(cx + x, cy + y)) {
          world.geos.get(x + cx, y + cy)
            .sym().draw(y + dim.y, x + dim.x);
        } else {
          Sym(' ', Col.TEXT).draw(y + dim.y, x + dim.x);
        }
      }
    }
    
    n.attrset(n.COLOR_PAIR(Col.TEXT));
    n.mvprintw(dim.y + padH, dim.x + padW, "X");
  }
}

class Nearby : Box {
  World world;
  
  this(World world) {
    this.world = world;
  }
  
  int w() const { return 12; }
  
  void draw(Dim dim) {
    n.attrset(n.COLOR_PAIR(Col.TEXT));
    n.attron(n.A_BOLD);
    n.mvprintw(dim.y, dim.x, "- Nearby: -");
    n.attroff(n.A_BOLD);
  }
}

class Stats : Box {
  World world;
  
  this(World world) {
    this.world = world;
  }
  
  void draw(Dim dim) {
    n.mvprintw(dim.y, dim.x, "Stats!");
  }
}
