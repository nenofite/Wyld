module wyld.map;

import wyld.main;
import wyld.screen;
import wyld.layout;
import wyld.menu;

import n = ncs.curses;

class MapScreen : Screen {
  List gui;
  World world;
  Menu menu;
  uint vx, vy;
  
  this(World world) {
    this.world = world;
    vx = world.xToGeo(world.player.x);
    vy = world.yToGeo(world.player.y);
    
    gui = new List();
    gui.horiz = true;
    gui.rtl = true;
    menu = new Menu([
      Entry('c', "Center on player", (ScrStack stack) {
        vx = world.xToGeo(world.player.x);
        vy = world.yToGeo(world.player.y);
      }),
    ]);
    gui.addChild(menu);
    gui.addChild(new VBar());
    gui.addChild(new Map());
  }
  
  void update(ScrStack stack) {
    gui.draw(Box.Dim(0, 0, n.COLS, n.LINES));
    
    char key = cast(char) n.getch();
    switch (key) {
      case '8':
        vy--;
        break;
      case '9':
        vy--;
        vx++;
        break;
      case '6':
        vx++;
        break;
      case '3':
        vy++;
        vx++;
        break;
      case '2':
        vy++;
        break;
      case '1':
        vy++;
        vx--;
        break;
      case '4':
        vx--;
        break;
      case '7':
        vy--;
        vx--;
        break;
      case 27:  // 27 is the escape key
        stack.pop();
        break;
      default:
        menu.update(stack, key);
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
