module wyld.layout;

import wyld.main;

import std.algorithm: reduce, map, max;
import std.string: toStringz;

abstract class Box {
  int w, h;

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
  
  void pack() {
    if (horiz) {
      w = reduce!("a + b")(map!("a.w")(children));
      h = reduce!(max)(map!("a.h")(children));
    } else {
      w = reduce!(max)(map!("a.w")(children));
      h = reduce!("a + b")(map!("a.h")(children));
    }
  }
}


class WorldView : Box {
  World world;

  this(World world) {
    this.world = world;
    w = viewWidth;
    h = viewHeight;
  }
  
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
    h = 6;
  }
  
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
  auto top = new List();
  top.addChild(new WorldView(world));
  top.addChild(new OnGround(world));
  top.addChild(new Msgs(world));
  return top;
}

class Msgs : Box {
  World world;
  
  this(World world) {
    this.world = world;
  }
  
  void draw(Dim dim) {
    n.attrset(n.COLOR_PAIR(Col.TEXT));
    n.attron(n.A_BOLD);
    n.mvprintw(dim.y, dim.x, "- Messages: -");
    n.attroff(n.A_BOLD);
    for (int i = 1; i < dim.h; i++) {
      clearLine(dim.y + i);
      if (i - 1 < world.msgs.length) {
        n.mvprintw(dim.y + i, dim.x, toStringz(world.msgs[i-1]));
      }
    }
  }
}
