module wyld.screen;

import wyld.main;
import wyld.layout;
import wyld.format;
import wyld.map;
import wyld.menu;

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
  List hud;
  Menu menu;
  
  this(World world) {
    this.world = world;
    
    hud = new List();
    hud.rtl = true;
    hud.addChild(new Msgs(world));
    hud.addChild(new HBar(true, " - Messages -"));
    {
      auto menuPane = new List();
      hud.addChild(menuPane);
      menuPane.rtl = true;
      menuPane.horiz = true;
      menu = new MainMenu(world);
      menuPane.addChild(menu);
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
          cols.addChild(new VBar(false));
          {
            auto rows = new List();
            cols.addChild(rows);
            rows.addChild(new Minimap(world));
            rows.addChild(new Nearby(world));
          }
          cols.addChild(new VBar(false));
          cols.addChild(new Stats(world));
        }
      }
    }
  }
  
  void update(ScrStack stack) {
    clearScreen();
    hud.draw(Box.Dim(0, 0, n.COLS, n.LINES));

    char key = cast(char) n.getch();
    n.flushinp();
    switch (key) {
      //case n.KEY_UP:
      case '8':
        world.player.upd = world.player.chmove(0, -1, world);
        break;
      //case n.KEY_DOWN:
      case '2':
        world.player.upd = world.player.chmove(0, 1, world);
        break;
      //case n.KEY_LEFT:
      case '4':
        world.player.upd = world.player.chmove(-1, 0, world);
        break;
      //case n.KEY_RIGHT:
      case '6':
        world.player.upd = world.player.chmove(1, 0, world);
        break;
      //case n.KEY_HOME:
      case '7':
        world.player.upd = world.player.chmove(-1, -1, world);
        break;
      //case n.KEY_PPAGE:
      case '9':
        world.player.upd = world.player.chmove(1, -1, world);
        break;
      //case n.KEY_B2:
      case '5':
        world.player.upd = new Update(100, null);
        break;
      //case n.KEY_END:
      case '1':
        world.player.upd = world.player.chmove(-1, 1, world);
        break;
      //case n.KEY_NPAGE:
      case '3':
        world.player.upd = world.player.chmove(1, 1, world);
        break;
      case n.KEY_RESIZE:
      case 154:
        clearScreen();
        break;
      default:
        if (!menu.update(stack, key))
          world.barMsg(
            format("Unknown key: %d '%s'", cast(int) key, key)
          );
        break;
    }
    
    runUpdates();    
    n.refresh();
  }
  
  void runUpdates() {
    while (world.player.upd !is null) {
      world.update();
      hud.draw(Box.Dim(0, 0, n.COLS, n.LINES));
      n.refresh();
      Thread.sleep(dur!("nsecs")(500));
    }
  }
}
