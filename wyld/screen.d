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
  
    name = "";
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
          world.player.upd = mkUpdate(Time.minutes(1), cast(void delegate(World)) null);
          menu.updateWorldFast();
          return Menu.Mode.Return();
        })
      ]),
      cast(Menu.Mode) new BasicMode('Q', "Quit game", 
      (char, Menu menu) {
        menu.stack = [];
        return Menu.Mode.Return();
      }),
      new SkillsMenu()
    ];
  }
}

class SkillsMenu : Menu.Mode {
  Player player;
  
  this() {
    name = "Skills";
    key = 'k';
  }
  
  void init(Menu menu) {
    player = menu.world.player;
    
    sub = [new SkillsStats()];
    foreach (s; player.skills) {
      sub ~= s.use;
    }
  }
  
  Menu.Mode.Return update(char, Menu) {
    return Menu.Mode.Return(true);
  }
}

class SkillsStats : Menu.Mode {
  Player player;
  
  this() {
    name = "Skill stats";
    key = 's';
  }
  
  void init(Menu menu) {
    player = menu.world.player;
    
    List rows = new List();
    ui = rows;
    
    foreach (s; player.skills) {
      rows.addChild(new class(s) Box {
        ActiveSkill s;
        
        this(ActiveSkill s) {
          this.s = s;
        }
      
        int h() const { return 1; }
        
        void draw(Dim dim) {
          n.attrset(n.COLOR_PAIR(Col.TEXT));
          n.mvprintw(dim.y, dim.x, toStringz(s.name ~ ": "));
          s.level.draw();
        }
      });
    }
  }
  
  Menu.Mode.Return update(char, Menu) {
    return Menu.Mode.Return(true);
  }
}