module wyld.screen;

import wyld.main;
import wyld.layout;
import wyld.format;

import n = ncs.ncurses;

class ScrStack {
  Screen[] stack;
  alias stack this; 
  
  void update() {
    assert(stack.length > 0);
    stack[$-1].update(this);
  }
  
  void pop() {
    assert(stack.length > 0);
    stack = stack[0 .. $-1];
  }
}

abstract class Screen {
  void update(ScrStack);
}


class MainScreen : Screen {
  World world;
  Box hud;
  
  this(World world) {
    this.world = world;
    hud = mainView(world);
  }
  
  void update(ScrStack stack) {
    hud.draw(Box.Dim(0, 0, n.COLS, n.LINES));

    bool cont = true;
    while (cont) {
      int key = n.getch();
      n.flushinp();
      switch (key) {
        //case n.KEY_UP:
        case '8':
          world.player.upd = world.player.move(0, -1, world);
          break;
        //case n.KEY_DOWN:
        case '2':
          world.player.upd = world.player.move(0, 1, world);
          break;
        //case n.KEY_LEFT:
        case '4':
          world.player.upd = world.player.move(-1, 0, world);
          break;
        //case n.KEY_RIGHT:
        case '6':
          world.player.upd = world.player.move(1, 0, world);
          break;
        //case n.KEY_HOME:
        case '7':
          world.player.upd = world.player.move(-1, -1, world);
          break;
        //case n.KEY_PPAGE:
        case '9':
          world.player.upd = world.player.move(1, -1, world);
          break;
        //case n.KEY_B2:
        case '5':
          world.player.upd = new Update(100, null);
          break;
        //case n.KEY_END:
        case '1':
          world.player.upd = world.player.move(-1, 1, world);
          break;
        //case n.KEY_NPAGE:
        case '3':
          world.player.upd = world.player.move(1, 1, world);
          break;
        case 'Q':
          cont = false;
          break;
        case n.KEY_RESIZE:
          clearScreen();
          break;
        default:
          world.barMsg(format("Unknown key: %d '%s'", key, cast(char) key));
          break;
      }
      
      n.attrset(n.COLOR_PAIR(Col.TEXT));
      clearScreen();
      hud.draw(Box.Dim(0, 0, n.COLS, n.LINES));
      while (world.player.upd !is null) {
        world.update();
        hud.draw(Box.Dim(0, 0, n.COLS, n.LINES));
        n.refresh();
        Thread.sleep(dur!("nsecs")(500));
      }
      
      n.refresh();
    }
    stack.pop();
  }
}
