/// The main code for starting up the game
module wyld.main;

import wyld.core.menu;
import wyld.ent;

import ncs = ncs.ncurses;


Player player;


/// Start the game
void main() {
  /// Start up ncurses
  ncs.initscr();
  scope (exit) ncs.endwin();
  ncs.cbreak();
  ncs.keypad(ncs.stdscr, true);
  ncs.noecho();

  /// Create the menu and set it globally
  Menu.menu = new Menu();
  Menu.menu.addScreen(new ScreenSequence("seqr Tar!!", [
    
  ]));
  Menu.menu.loop();
}