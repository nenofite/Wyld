module wyld.layout;

import wyld.main;
import wyld.menu;
import wyld.screen;
import wg = wyld.worldgen;
import wyld.map;
import wyld.format;

import std.algorithm: reduce, map, max, sort;
import std.string: toStringz;
import tc = std.typecons;

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
  Overlay[] overlays;

  this(World world, Menu menu) {
    this.world = world;
    this.menu = menu;
    overlays = [new BaseDraw()];
  }
  
  int w() const { return viewWidth; }
  int h() const { return viewHeight; }
  
  void draw(Dim dim) {
    int cx = world.player.x - (viewWidth / 2),
        cy = world.player.y - (viewHeight / 2);
    int bx = dim.x,
        by = dim.y;

    for (int y = 0; y < viewHeight; y++) {
      n.move(y + by, bx);
      for (int x = 0; x < viewWidth; x++) {
        Sym s = Sym(' ', Col.TEXT);
        if (menu.world.stat.inside(cx + x, cy + y)) {
          foreach_reverse (overlay; overlays) {
            auto sn = overlay.dense(Coord(cx + x, cy + y), menu);
            if (!sn.isNull) {
              s = sn;
              break;
            }
          }
        }
        n.attrset(n.COLOR_PAIR(s.color));
        n.addch(s.ch);
      }
    }
    
    foreach (overlay; overlays) {
      foreach (disp; overlay.sparse(menu)) {
        disp.sym.draw(disp.coord.y + by - cy,
                      disp.coord.x + bx - cx);
      }
    }
    
    overlays = [new BaseDraw()];
    
    foreach (skill; world.player.skills) {
      if (skill.passive !is null) {
        if (skill.passive.isOn) {
          auto overlay = skill.passive.overlay();
          if (overlay !is null)
            overlays ~= skill.passive.overlay;
        }
      }
    }
  }
  
  static abstract class Overlay {
    tc.Nullable!Sym dense(Coord, Menu) { 
      return tc.Nullable!Sym(); 
    }
    
    CoordSym[] sparse(Menu) { 
      return [];
    }
  }
  
  static class BaseDraw : Overlay {
    tc.Nullable!Sym dense(Coord c, Menu menu) {
      tc.Nullable!Sym sym;
      sym = menu.world.baseAt(c.x, c.y);
      auto s = menu.world.stat.get(c.x, c.y).statEnts;
      if (s.length > 0) sym = s[$-1].sym;
      return sym;
    }
    
    CoordSym[] sparse(Menu menu) {
      CoordSym[] entSyms;
      foreach (ent; menu.world.movingEnts) {
        if (menu.world.stat.inside(ent.x, ent.y)) {
          entSyms ~= CoordSym(Coord(ent.x, ent.y), ent.sym);
        }
      }
      return entSyms;
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
