module wyld.screen;

import wyld.main;
import wyld.layout;
import wyld.format;
import wyld.map;
import wyld.menu;

import n = ncs.ncurses;
import std.algorithm: min;

class MainScreen : Menu.Mode {
  World world;
  WorldView worldView;
  
  this(World world, Menu menu) {
    this.world = world;
  
    name = "";
    sub = makeMenu();
    closeOnEsc = false;
  
    ui = new Ui(menu);
  }
  
  Menu.Mode.Return update(char key, Menu menu) {
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
      new SkillsMenu(),
      new Items('i', "Inventory", () { return world.player.contents; }),
      new Items('g', "Ground", () { 
        auto ret = world.entsNear(world.player.x, world.player.y); 
        ret.remove(world.player);
        return ret;
      }),
      cast(Menu.Mode) new BasicMode('Q', "Quit game", 
          (char, Menu menu) {
        menu.stack = [];
        return Menu.Mode.Return();
      }),
    ];
  }
  
  class Ui : Menu.Ui {
    this(Menu menu) {
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
            worldView = new WorldView(world, menu);
            rows.addChild(worldView);
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
    
    void update(char key, Menu menu) {
      bool isDir;
      auto dir = getDirKey(key, isDir);
      if (isDir) {
        menu.world.player.upd = menu.world.player.chmove(dir.x, dir.y, menu.world);
      } else if (key == '5') {
      }
      
      menu.updateWorld();
    }
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
}

class SkillsStats : Menu.Mode {
  Player player;
  
  this() {
    name = "Skill stats";
    key = 's';
  }
  
  void init(Menu menu) {
    player = menu.world.player;
    
    ui = new class() Menu.Ui {
      this() {
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
      
      void update(char key, Menu) {}
    };
  }
}

class Inv : Menu.Mode {
  this() {
    name = "Inventory";
    key = 'i';
  }
  
  void init(Menu menu) {
    sub = [];
    char k = 'a';
    foreach (i; menu.world.player.contents) {
      sub ~= new BasicMode(k++, i.name, []);
    }
  }
}

class Get : Menu.Mode {
  this() {
    name = "Get";
    key = 'g';
  }
  
  void init(Menu menu) {
    sub = [];
    char k = 'a';
    foreach (i; menu.world.entsNear(menu.world.player.x, 
        menu.world.player.y)) {
      if (i !is menu.world.player)
        sub ~= new class(i, k++) Menu.Mode {
          Ent i;
          this(Ent i, char k) {
            this.i = i;
            key = k;
            name = i.name;
            getKeys = false;
          }
          
          Menu.Mode.Return update(char, Menu menu) {
            auto res = menu.world.player.add(i);
            if (res == wyld.main.Container.AddRet.SUCCESS) {
              menu.world.movingEnts.remove(i);
            }
            return Menu.Mode.Return();
          }
        };
    }
  }
  
  Menu.Mode.Return update(char, Menu) {
    return Menu.Mode.Return(false);
  }
}

class Items : Menu.Mode {
  Ent[] delegate() items;
  
  this(char key, string name, Ent[] delegate() items) {
    this.key = key;
    this.name = name;
    this.items = items;
  }
  
  void preUpdate(Menu) {
    assert(items != null);
    sub = [];
    char k = 'a';
    foreach (i; items()) {
      sub ~= new ItemInteract(i, k++);
    }
  }
}

class ItemInteract : Menu.Mode {
  Ent item;
  
  this(Ent item, char key) {
    this.item = item;
    this.key = key;
    name = item.name;
  }
  
  void init(Menu menu) {
    auto p = menu.world.player;
    sub = [];
    
    sub ~= new BasicMode('g', "Get", () {
      auto res = item.reparent(p);
      switch (res) {
        case wyld.main.Container.AddRet.SUCCESS:
          menu.world.barMsg(format("You pick up the %s.", item.name));
          break;
        case wyld.main.Container.AddRet.NO_ROOM:
          menu.world.barMsg("You don't have room to carry that.");
          break;
        case wyld.main.Container.AddRet.WRONG_TYPE:
          menu.world.barMsg("You'll need something else to carry that.");
          break;
        default:
          assert(false);
          break;
      }
      return Menu.Mode.Return();
    });
    
    if (item.drinkCo != 0) {
      sub ~= new BasicMode('q', "Drink", () {
        auto drinkAmt = min(item.drink, p.thirst.max - p.thirst);
        assert(drinkAmt >= 0);
        p.thirst += drinkAmt;
        item.size -= drinkAmt / item.drinkCo;
        assert(item.size >= 0);
        //TODO give units in message
        menu.world.barMsg(format("You drink %d of the %s.", drinkAmt, item.name));
        return Menu.Mode.Return();
      });
    }
  }
}