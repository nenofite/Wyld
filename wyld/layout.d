module wyld.layout;

import wyld.main;
import wyld.menu;
import wyld.screen;
import wg = wyld.worldgen;
import wyld.map;
import wyld.format;

import std.algorithm: reduce, map, max, sort;
import std.string: toStringz;

abstract class Box {
  int w() const { return 0; }
  int h() const { return 0; }

  void draw(Dim);
  
  struct Dim {
    int x, y, w, h;
    uint drawTick;
    
    //Explicitly define constructor to make sure that all fields are
    // given
    this(int x, int y, int w, int h, uint drawTick) {
      this.x = x;
      this.y = y;
      this.w = w;
      this.h = h;
      this.drawTick = drawTick;
    }
    
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
        b.draw(Dim(x, dim.y, b.w, dim.h, dim.drawTick));
        if (!rtl) x += b.w;
      }
      int width = (rtl ? x - dim.x : dim.x2() - x + 1);
      if (rtl) x = dim.x;
      children[$-1].draw(Dim(x, dim.y, width, dim.h, dim.drawTick));
    } else {
      int y = rtl ? dim.y2() + 1 : dim.y;
      for (int i = 0; i < children.length - 1; i++) {
        auto b = children[i];
        if (rtl) y -= b.h;
        b.draw(Dim(dim.x, y, dim.w, b.h, dim.drawTick));
        if (!rtl) y += b.h;
      }
      int height = (rtl ? y - dim.y : dim.y2() - y + 1);
      if (rtl) y = dim.y;
      children[$-1].draw(Dim(dim.x, y, dim.w, height, dim.drawTick));
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
  Menu menu;

  this(World world, Menu menu) {
    this.world = world;
    this.menu = menu;
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
          auto stat = world.stat.get(cx + x, cy + y);
          if (stat.statEnts.length > 0)
            s = stat.statEnts[$-1].sym();
          if (m.abs(x - viewWidth / 2) <= 3 && m.abs(y - viewHeight / 2) <= 3
              && stat.tracks.source !is null
              && stat.tracks.source !is world.player)
            if (stat.tracks.num % 10
                == (menu.drawTick / 10) % 10) {
              s = Tracks.sym;
            }
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
    
    foreach (d; world.disp) {
      if (world.inView(d.coord.x, d.coord.y)) {
        d.sym.draw(d.coord.y + by - cy, d.coord.x + bx - cx);
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
      if (msgIndex < world.msgs.length) {
        n.mvprintw(dim.y + i, dim.x, toStringz(world.msgs[msgIndex]));
        msgIndex++;
      }
    }
  }
}

class VBar : Box {
  bool visible;
  
  this(bool visible = true) {
    this.visible = visible;
  }

  int w() const { return 1; }
  
  void draw(Dim dim) {
    if (visible) {
      n.attrset(n.COLOR_PAIR(Col.BORDER));
      for (int y = dim.y; y <= dim.y2(); y++) {
        n.mvprintw(y, dim.x, " ");
      }
    }
  }
}

class HBar : Box {
  string label;
  bool visible;
  
  this(bool visible = true, string label = "") {
    this.visible = visible;
    this.label = label;
  }

  int h() const { return 1; }
  
  void draw(Dim dim) {
    if (visible) {
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
}

class TimeBar : Box {
  World world;
  
  this(World world) {
    this.world = world;
  }
  
  int h() const { return 1; }
  
  void draw(Dim dim) {
    if (world.time.isDay()) {
      if (world.time.isDawn() || world.time.isDusk()) {
        n.attrset(n.COLOR_PAIR(Col.RED_BG));
      } else {
        n.attrset(n.COLOR_PAIR(Col.BLUE_BG));
      }
    } else {
      n.attrset(n.COLOR_PAIR(Col.WHITE));
    }
    
    n.move(dim.y, dim.x);
    for (int x = 0; x < dim.w; x++) {
      n.addch(' ');
    }
    
    uint moon = world.time.moon() * dim.w / Time.sunMoonMax,
         sun = world.time.sun() * dim.w / Time.sunMoonMax;
    
    n.mvprintw(dim.y, dim.x + moon, "C");
    if (world.time.isDay()) {
      n.attrset(n.COLOR_PAIR(Col.YELLOW_BG));
      n.mvprintw(dim.y, dim.x + sun, "O");
    }
  }
}

class Minimap : Box {
  World world;
  
  const int mapW = 11,
            mapH = 11,
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
          world.geos.modify(x + cx, y + cy, (wg.Geo g) {
            g.discovered = true;
            return g;
          });
        } else {
          Sym(' ', Col.TEXT).draw(y + dim.y, x + dim.x);
        }
      }
    }
    
    n.attrset(n.COLOR_PAIR(Col.TEXT));
    if (dim.drawTick % 100 < 50)
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
    struct EntDist {
      Ent ent;
      int dist;
      
      alias ent this;
    }
    EntDist[] ents;
    foreach (ent; world.player.nearby(world)) {
      ents ~= EntDist(ent, dist(ent.x, ent.y, world.player.x, world.player.y));
    }
    sort!("a.dist < b.dist")(ents);
    
    EntDist[] nearby;
    EntDist[][Dir] far;
    foreach (ent; ents) {
      if (world.inView(ent.x, ent.y)) {
        nearby ~= ent;
      } else {
        far[getDir(world.player.x, world.player.y, ent.x, ent.y)] 
          ~= ent;
      }
    }
    
    int y = dim.y - 1;
    void list(Ent e) {
      e.sym().draw(++y, dim.x);
      n.mvprintw(y, dim.x + 2, toStringz(e.name));
    }
    
    if (nearby.length > 0) {
      n.attrset(n.COLOR_PAIR(Col.BLUE));
      n.mvprintw(++y, dim.x, "NEARBY");
      foreach (e; nearby) {
        list(e);
      }
    }
    foreach (Dir d, ents; far) {
      n.attrset(n.COLOR_PAIR(Col.BLUE));
      n.mvprintw(++y, dim.x, toStringz(dirName(d)));
      foreach (e; ents) {
        list(e);
      }
    }
  }
}

class Stats : Box {
  World world;
  
  this(World world) {
    this.world = world;
  }
  
  void draw(Dim dim) {
    int y = dim.y - 1;
    n.attrset(n.COLOR_PAIR(Col.TEXT));
    n.mvprintw(++y, dim.x, "HP: ");
    world.player.hp.draw();
    n.attrset(n.COLOR_PAIR(Col.TEXT));
    n.mvprintw(++y, dim.x, "SP: ");
    world.player.sp.draw();
    y++;
    n.attrset(n.COLOR_PAIR(Col.TEXT));
    n.mvprintw(++y, dim.x, "Thirst: ");
    world.player.thirst.draw();
    n.attrset(n.COLOR_PAIR(Col.TEXT));
    n.mvprintw(++y, dim.x, "Hunger: ");
    world.player.hunger.draw();
  }
}
