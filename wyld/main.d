/// The main code for starting up the game
module wyld.main;

import wyld.core.menu;
import wyld.core.world;
import wyld.ent;
import wyld.ui;
import wyld.worldgen;

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

  /// Generate the world
  world = generateWorld(7, 7, 3, 4);

  /// Create the menu and set it globally
  menu = new Menu();
  menu.addScreen(new MainScreen());
  menu.loop();
}