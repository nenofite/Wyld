module wyld.menu;

import wyld.layout;
import wyld.screen;
import wyld.main;

import std.string: toStringz;

class Menu : Box {
  Entry[][] entryStack;
  string[] title;
  
  this(string title, Entry[] entries = []) {
    this.title = [title];
    entryStack = [entries];
  }
  
  uint w() const { return 30; }
  
  void draw(Dim dim) {
    assert(title.length > 0);
    assert(entryStack.length > 0);
    auto entries = entryStack[$-1];
    n.attrset(n.COLOR_PAIR(Col.TEXT));
    n.move(dim.y, dim.x);
    for (int x = 0; x < dim.w; x++) n.addch(' ');
    n.attron(n.A_BOLD);
    n.mvprintw(dim.y, dim.x + 1, toStringz(title[$-1]));
    n.attroff(n.A_BOLD);
    for (int i = 1; i < dim.h; i++) {
      n.move(i + dim.y, dim.x);
      for (int x = 0; x < dim.w; x++) {
        n.addch(' ');
      }
      if (i - 1 < entries.length) {
        n.attrset(n.COLOR_PAIR(Col.GREEN));
        n.mvprintw(i + dim.y, dim.x + 1, "%c ", entries[i-1].key);
        n.attrset(n.COLOR_PAIR(Col.TEXT));
        n.printw(toStringz(entries[i-1].label));
      }
    }
  }
  
  bool update(char key, Screen scr, ScrStack stack) {
    assert(entryStack.length > 0);
    if (key == 27 && entryStack.length > 1) {  // 27 is the escape key
      entryStack = entryStack[0 .. $-1];
      title = title[0 .. $-1];
      return true;
    } else {
      foreach (e; entryStack[$-1]) {
        if (e.key == key) {
          assert(e.select !is null);
          auto sub = e.select(scr, stack);
          if (sub.length > 0) {
            entryStack ~= sub;
            title ~= e.label;
          }
          return true;
        }
      }
    }
    return false;
  }
}

struct Entry {
  char key;
  string label;
  
  Entry[] delegate(Screen, ScrStack) select;
  
  this(char key, string label, Entry[] delegate(Screen, ScrStack) select) {
    this.key = key;
    this.label = label;
    this.select = select;
  }
  
  this(char key, string label, void delegate(Screen, ScrStack) select) {
    Entry[] sel(Screen scr, ScrStack stack) {
      select(scr, stack);
      return [];
    }
    
    this(key, label, &sel);
  }
  
  this(char key, string label, Entry[] submenu) {
    Entry[] sel(Screen, ScrStack) {
      return submenu;
    }
    
    this(key, label, &sel);
  }
}
