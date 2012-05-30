module wyld.map;

import wyld.main;
import wyld.screen;
import wyld.layout;
import wyld.menu;

import n = ncs.curses;

class MapScreen : Menu.Mode {
  World world;
  
  uint vx, vy;
  
  this() {
    name = "Map";
    key = 'm';
    
    sub = [
      new BasicMode('c', "Center on player", () {
        recenter();
        return Menu.Mode.Return();
      })
    ];
    
    ui = new Map();
  }
  
  void recenter() {
    vx = world.xToGeo(world.player.x);
    vy = world.yToGeo(world.player.y);
  }
  
  Menu.Mode.Return update(char key, Menu menu) {
    auto movement = getDirKey(key);
    vx += movement.x;
    vy += movement.y;
    
    return Menu.Mode.Return(true);
  }
  
  void init(Menu menu) {
    world = menu.world;
    recenter();
  }
  
  class Map : Box {
    void draw(Box.Dim dim) {
      uint cx = vx - dim.w / 2,
           cy = vy - dim.h / 2;
           
      for (int y = 0; y < dim.h; y++) {
        for (int x = 0; x < dim.w; x++) {
          if (cx + x == world.xToGeo(world.player.x) 
          && cy + y == world.yToGeo(world.player.y)) {
            Sym('X', Col.TEXT).draw(dim.y + y, dim.x + x);
          } else if (world.geos.inside(cx + x, cy + y)) {
            auto geo = world.geos.get(cx + x, cy + y);
            if (geo.discovered) {
              geo.sym().draw(dim.y + y, dim.x + x);
            } else {
              n.attron(n.A_BOLD);
              Sym('#', Col.WHITE).draw(dim.y + y, dim.x + x);
              n.attroff(n.A_BOLD);
            }
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
