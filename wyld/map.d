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
    
    ui = new class(this) Menu.Ui {
      this(MapScreen screen) {
        ui = new Map(screen);
      }
      
      void update(char key, Menu menu) {
        auto movement = getDirKey(key);
        vx += movement.x;
        vy += movement.y;
      }
    };
  }
  
  void recenter() {
    vx = world.xToGeo(world.player.x);
    vy = world.yToGeo(world.player.y);
  }
  
  Menu.Mode.Return update(char key, Menu menu) {
    return Menu.Mode.Return(true);
  }
  
  void init(Menu menu) {
    world = menu.world;
    recenter();
  }
  
  static class Map : Box {
    MapScreen screen;
    
    this(MapScreen screen) {
      this.screen = screen;
    }
  
    void draw(Box.Dim dim) {
      uint cx = screen.vx - dim.w / 2,
           cy = screen.vy - dim.h / 2;
           
      for (int y = 0; y < dim.h; y++) {
        for (int x = 0; x < dim.w; x++) {
          if (cx + x == screen.world.xToGeo(screen.world.player.x) 
          && cy + y == screen.world.yToGeo(screen.world.player.y)
          && dim.drawTick % 100 < 50) {
            Sym('X', Col.TEXT).draw(dim.y + y, dim.x + x);
          } else if (screen.world.geos.inside(cx + x, cy + y)) {
            auto geo = screen.world.geos.get(cx + x, cy + y);
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
