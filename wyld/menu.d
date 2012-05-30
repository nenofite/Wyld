module wyld.menu;

import wyld.layout;
import wyld.screen;
import wyld.main;

import std.string: toStringz;

class Menu {
  Mode[] stack;
  World world;
  
  List ui;
  
  this(World world) {
    this.world = world;
    ui = new List();
    ui.horiz = true;
    ui.rtl = true;
    
    ui.addChild(new MenuBox());
    ui.addChild(new VBar());
    ui.addChild(new DelegateBox());
  }
  
  void update() {
    clearScreen();
    ui.draw(Box.Dim(0, 0, n.COLS, n.LINES));
    n.refresh();
    
    assert(stack.length > 0);
    auto mode = stack[$-1];
    
    char key = '\0';
    
    if (mode.getKeys) {
      key = cast(char) n.getch();
      n.flushinp();
    }
    
    if (key == 27 // 27 is the escape key
    && mode.closeOnEsc) {
      stack = stack[0 .. $-1];
      return;
    } else {
      foreach (e; mode.sub) {
        if (e.key == key) {
          stack ~= e;
          e.init(this);
          return;
        }
      }
    }
    
    auto ret = mode.update(key, this);
    if (!ret.keep) {
      stack = stack[0 .. $-1];
    }
    if (ret.add.length > 0) stack ~= ret.add;
    foreach (added; ret.add) added.init(this);
    //TODO do we need this?
    
    ui.draw(Box.Dim(0, 0, n.COLS, n.LINES));
    n.refresh();
  }
  
  void updateWorld() {
    while (world.player.upd !is null) {
      world.update();
      clearScreen();
      ui.draw(Box.Dim(0, 0, n.COLS, n.LINES));
      n.refresh();
      Thread.sleep(dur!("nsecs")(500));
    }
  }
  
  class MenuBox : Box {
    uint w() const { return 30; }
    
    void draw(Dim dim) {
      assert(stack.length > 0);
      auto mode = stack[$-1];
      
      n.attrset(n.COLOR_PAIR(Col.TEXT));
      n.move(dim.y, dim.x);
      for (int x = 0; x < dim.w; x++) n.addch(' ');
      n.attron(n.A_BOLD);
      n.mvprintw(dim.y, dim.x + 1, toStringz(mode.name));
      n.attroff(n.A_BOLD);
      
      for (int i = 1; i < dim.h; i++) {
        n.move(i + dim.y, dim.x);
        for (int x = 0; x < dim.w; x++) {
          n.addch(' ');
        }
        if (i - 1 < mode.sub.length) {
          n.attrset(n.COLOR_PAIR(Col.GREEN));
          n.mvprintw(i + dim.y, dim.x + 1, "%c ", mode.sub[i-1].key);
          n.attrset(n.COLOR_PAIR(Col.TEXT));
          n.printw(toStringz(mode.sub[i-1].name));
        }
      }
    }
  }
  
  class DelegateBox : Box {
    void draw(Dim dim) {
      foreach_reverse (m; stack) {
        if (m.ui !is null) {
          m.ui.draw(dim);
          return;
        }
      }
      assert(false);
    }
  }
  
  static abstract class Mode {
    string name;
    char key;
    bool getKeys = true,
         closeOnEsc = true;
    
    Mode[] sub;
    Box ui;
    
    Return update(char key, Menu);
    void init(Menu) {}
    
    static struct Return {
      bool keep;
      Mode[] add;
    }
  }
}

class BasicMode : Menu.Mode {
  Menu.Mode.Return delegate(char key, Menu) upd;

  this(char key, string name, Menu.Mode[] sub) {
    this.key = key;
    this.name = name;
    this.sub = sub;
  }
  this(char key, string name, 
      Menu.Mode.Return delegate(char key, Menu) upd) {
    this.key = key;
    this.name = name;
    this.sub = sub;
    this.upd = upd;
    getKeys = false;
  }
  this(char key, string name, Menu.Mode.Return delegate() upd) {
    Menu.Mode.Return upd2(char, Menu) {
      return upd();
    }
    this(key, name, &upd2);
  }
  
  Menu.Mode.Return update(char key, Menu menu) {
    if (upd !is null) {
      return upd(key, menu);
    } else {
      return Menu.Mode.Return(true);
    }
  }
}