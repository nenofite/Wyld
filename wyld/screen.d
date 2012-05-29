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
  ControlStack controls;
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
      menu = makeMenu();
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
    
    controls = new ControlStack();
  }
  
  void update(ScrStack stack) {
    clearScreen();
    hud.draw(Box.Dim(0, 0, n.COLS, n.LINES));
    
    if (controls.length > 0) {
      controls[$-1].update(world, controls);
      //if (controls[$-1].runUpdates) runUpdates();
    } else {
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
    }
    
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
  
  Menu makeMenu() {
    return new Menu([
      Entry('m', "Map", (ScrStack scr) { scr ~= new MapScreen(world); }),
      Entry('D', "Debugging", null, [
        Entry('r', "Reveal map", (ScrStack scr) {
          world.geos.map((wg.Geo g) {
            g.discovered = true;
            return g;
          });
          world.barMsg("Map revealed.");
        }),
        Entry('t', "Pass time", (ScrStack scr) {
          world.player.upd = new Update(Time.minutes(1), null);
          while (world.player.upd !is null)
            world.update();
        })
      ]),
      Entry('Q', "Quit game", (ScrStack scr) { scr.pop(); })
    ]);
  }
}

abstract class Controls {
  bool runUpdates;
  void update(World, ControlStack);
}

class RunCommand : Controls {
  Command cmd;
  bool gotUsing, gotTo, gotDest, gotDir;
  bool stacked;
  
  this(Command cmd) {
    this.cmd = cmd;
  }
  
  void update(World world, ControlStack stack) {
    if (!stacked) {
      if (cmd.takesUsing) {
        //TODO
      }
      if (cmd.takesTo) {
        //TODO
      }
      if (cmd.takesDest) {
        stack ~= new ChooseDest(&cmd.dest);
      }
      if (cmd.takesDir) {
        //stack ~= new ChooseDir(&cmd.dir);
      }
      stacked = true;
    } else {
      cmd.run(world);
      stack.pop();
    }
  }
}

class ChooseDest : Controls {
  Coord *dest;
  
  this(Coord *dest) {
    this.dest = dest;
  }

  void update(World world, ControlStack stack) {
    char key = cast(char) n.getch();
    n.flushinp();
    
    if (key == 27) {
      //*succ = false;
      stack.pop();
    } else if (key == '\n') {
      //*succ = true;
      stack.pop();
    } else {
      dest.add(getDirKey(key));
      
      world.disp ~= Disp(Sym('X', Col.YELLOW), *dest);
    }
  }
}

class ControlStack {
  Controls[] stack;
  alias stack this;
  
  void pop() {
    stack = stack[0 .. $-1];
  }
}
