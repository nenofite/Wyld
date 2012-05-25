module wyld.menu;

import wyld.layout;
import wyld.screen;
import wyld.main;

import std.string: toStringz;

class Menu : Box {
  Entry[] entries;
  
  this(Entry[] entries = []) {
    this.entries = entries;
  }
  
  uint w() const { return 30; }
  
  void draw(Dim dim) {
    n.attrset(n.COLOR_PAIR(Col.TEXT));
    for (int i = 0; i < dim.h; i++) {
      n.move(i + dim.y, dim.x);
      n.addch(' ');
      for (int x = 1; x < dim.w; x++) {
        n.addch(' ');
      }
      if (i < entries.length) {
        n.attrset(n.COLOR_PAIR(Col.GREEN));
        n.mvprintw(i + dim.y, dim.x + 1, "%c ", entries[i].key);
        n.attrset(n.COLOR_PAIR(Col.TEXT));
        n.printw(toStringz(entries[i].label));
      }
    }
  }
  
  bool update(ScrStack stack, char key) {
    foreach (e; entries) {
      if (e.key == key) {
        e.onSelect(stack);
        return true;
      }
    }
    return false;
  }
}

struct Entry {
  char key;
  string label;
  
  void delegate(ScrStack) onSelect;
}
