module wyld.main;

import wyld.core.menu;

import ncs = ncs.ncurses;


void main() {
  ncs.initscr();
  scope (exit) ncs.endwin();
  ncs.cbreak();
  ncs.keypad(ncs.stdscr, true);
  ncs.noecho();

  auto m = new Menu();
  m.addScreen(new ScreenSequence("seqr Tar!!", [
    
  ]));
  m.loop();
}