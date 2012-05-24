module wyld.map;

import wyld.main;
import wyld.screen;
import wyld.layout;

import n = ncs.curses;

class MapScreen : Screen {
  List gui;
  World world;
  uint vx, vy;
  
  this(World world) {
    this.world = world;
    vx = world.xToGeo(world.player.x);
    vy = world.yToGeo(world.player.y);
    
    gui = new List();
    gui.horiz = true;
    gui.rtl = true;
    gui.addChild(new Menu(world));
    gui.addChild(new VBar());
    gui.addChild(new Map());
  }
  
  void update(ScrStack stack) {
    gui.draw(Box.Dim(0, 0, n.COLS, n.LINES));
    
    switch (n.getch()) {
      default:
        break;
    }
    n.flushinp();
  }
  
  class Map : Box {
    void draw(Box.Dim dim) {
      uint cx = vx - dim.w / 2,
           cy = vy - dim.h / 2;
           
      for (int y = 0; y < dim.h; y++) {
        for (int x = 0; x < dim.w; x++) {
          if (world.geos.inside(cx + x, cy + y)) {
            world.geos.get(cx + x, cy + y).sym()
              .draw(dim.y + y, dim.x + x);
          } else {
            if (y % 3 == 0 && x % 3 == 0) {
              Sym('.', Col.BLUE).draw(dim.y + y, dim.x + x);
            } else {
              n.mvprintw(dim.y + y, dim.x + x, " ");
            }
          }
        }
      }
    }
  }
}
