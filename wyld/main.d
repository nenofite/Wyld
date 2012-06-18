/// The main code for starting up the game
module wyld.main;

import wyld.core.common;
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
  ncs.noecho();
  ncs.keypad(ncs.stdscr, true);
  ncs.curs_set(false);
  initColor();

  ncs.timeout(10);
  
  /// Generate the world
  world = generateWorld(7, 7, 3, 4);
  
  player = new Player();
  
  world.add(player);
  
  assert(world.staticGrid !is null);

  /// Create the menu and set it globally
  menu = new Menu([], null);
  menu.addScreen(new MainScreen());
  menu.loop();
}


void initColor() {
  assert(ncs.has_colors(), "Couldn't get color support.");

  ncs.start_color();
  ncs.init_pair(Color.Text, ncs.COLOR_WHITE, ncs.COLOR_BLACK);
  ncs.init_pair(Color.Border, ncs.COLOR_BLACK, ncs.COLOR_WHITE);
  ncs.init_pair(Color.Blue, ncs.COLOR_BLUE, ncs.COLOR_BLACK);
  ncs.init_pair(Color.Green, ncs.COLOR_GREEN, ncs.COLOR_BLACK);
  ncs.init_pair(Color.Red, ncs.COLOR_RED, ncs.COLOR_BLACK);
  ncs.init_pair(Color.Yellow, ncs.COLOR_YELLOW, ncs.COLOR_BLACK);
  ncs.init_pair(Color.White, ncs.COLOR_WHITE, ncs.COLOR_BLACK);
  ncs.init_pair(Color.BlueBg, ncs.COLOR_WHITE, ncs.COLOR_BLUE);
  ncs.init_pair(Color.YellowBg, ncs.COLOR_WHITE, ncs.COLOR_YELLOW);
  ncs.init_pair(Color.YellowBBg, ncs.COLOR_BLACK, ncs.COLOR_YELLOW);
  ncs.init_pair(Color.RedBg, ncs.COLOR_WHITE, ncs.COLOR_RED);
  ncs.init_pair(Color.RedBBg, ncs.COLOR_BLACK, ncs.COLOR_RED);
}