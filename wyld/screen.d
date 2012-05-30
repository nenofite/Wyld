module wyld.screen;

import wyld.main;
import wyld.layout;
import wyld.format;
import wyld.map;
import wyld.menu;

import n = ncs.ncurses;

class MainScreen : Menu.Mode {
  World world;
  
  this(World world) {
    this.world = world;
  
    name = "Main screen";
    key = 'M';
    sub = makeMenu();
    closeOnEsc = false;
  
    auto list = new List();
    ui = list;
    list.rtl = true;
    list.addChild(new Msgs(world));
    list.addChild(new HBar(true, " - Messages -"));
    {
      auto timeRow = new List();
      list.addChild(timeRow);
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
  
  Menu.Mode.Return update(char key, Menu menu) {
    bool isDir;
    auto coord = getDirKey(key, isDir);
    if (isDir) {
      world.player.upd = world.player.chmove(coord.x, coord.y, world);
    }
    
    menu.updateWorld();
    return Menu.Mode.Return(true);
  }
  
  Menu.Mode[] makeMenu() {
    return [
      new MapScreen(),
      cast(Menu.Mode) new BasicMode('D', "Debugging", [
        new BasicMode('r', "Reveal map", () {
          world.geos.map((wg.Geo g) {
            g.discovered = true;
            return g;
          });
          world.barMsg("Map revealed.");
          return Menu.Mode.Return();
        }),
        new BasicMode('t', "Pass time", (char, Menu menu) {
          world.player.upd = new Update(Time.minutes(1), null);
          menu.updateWorld();
          return Menu.Mode.Return();
        })
      ]),
      cast(Menu.Mode) new BasicMode('Q', "Quit game", 
      (char, Menu menu) {
        menu.stack = [];
        return Menu.Mode.Return();
      })
    ];
  }
}