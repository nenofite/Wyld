/// The concrete UI for the game
///
/// This is the concrete code, whereas the code in wyld.core.menu and
/// wyld.core.layout is the abstract stuff forming the base of the 
/// code in here.
module wyld.ui;

import wyld.core.layout;
import wyld.core.menu;

import ncs = ncs.ncurses;
import std.string: toStringz;


/// The main UI that the player sees while playing the game
///
/// This includes the world view, time of day, player stats, etc.
///
/// Not to be confused with the main menu
class MainScreen : Menu.Screen {
  this() {
    super("Main", new Ui());
  }
  
  Menu.Entry[] entries() {
    return []; // TODO
  }
  

  /// The visible part of the UI
  static class Ui : Menu.Ui {
    this() {
      ui = new List(false, false, [
        new TimeBar(),
        new List(true, false, [
          new List(false, false, [
            new WorldView(),
            new OnGround()
          ]),
          new Separator(false),
          new List(false, false, [
            new Minimap(),
            new Nearby()
          ]),
          new Stats()
        ])
      ]);
    }
    
    
    /// This catches the numpad keys used for movement
    ///
    /// By placing this code in here, all submenus of MainScreen can
    /// still pass on user input to it so the player can still move
    /// while inside a submenu
    bool input(char key) {
      bool isDir;
      auto dir = directionFromKey(key, isDir);
      
      if (isDir) {
        player.update = player.move(coordFromDirection(dir));
        //Menu.menu.updateWorld();
        // TODO when to update world?
      }
      
      return isDir;
    }
  }
}


/// Displays the sky overhead with sun and moon to indicate time of day
class TimeBar : Box {
  int height() {
    return 1;
  }
  
  
  void draw(Dimension dim) {
    /// Figure out which color to paint the sky
    if (World.time.isDay) {
      if (World.time.isDawn || World.time.isDusk) {
        setColor(Color.RedBg);
      } else {
        setColor(Color.BlueBg);
      }
    } else {
      setColor(Color.White);
    }
    
    /// Paint the sky background
    dim.fill();
    
    /// Figure out where the sun and moon are and paint them
    int sun = cast(int) (World.time.sunPosition * dim.width);
    int moon = cast(int) (World.time.moonPosition * dim.width);
    
    ncs.mvaddch(dim.y, dim.x + moon, 'C');
    
    if (World.time.isDay) {
      ncs.move(dim.y, dim.x + sun);
      Sym('O', Col.YellowBg).draw();
    }
  }
}


/// Displays the ents at the player's feet
class OnGround : Box {
  int height() {
    return 6;
  }
  
  
  void draw(Dimension dim) {
    string[] ents;
    
    /// Make sure the player isn't inside a location
    assert(!player.isInside);
    /// Find the names of all the ents on the same space as the player
    foreach (ent; World.entsAt(player.coord)) {
      if (ent !is player) {
        ents ~= ent.name;
      }
    }
    
    /// Draw the title
    setColor(Color.Text);
    
    ncs.attron(ncs.A_BOLD);
    ncs.mvprintw(dim.y, dim.x, " - On Ground: - ");
    ncs.attroff(ncs.A_BOLD);
    
    /// Draw the list of ent names
    int y = dim.y + 1;
    
    foreach (entName; ents) {
      ncs.mvprintw(y, dim.x, toStringz(entName));
      ++y;
    }
  }
}


/// Displays the nearby dynamic Ents that are visible to the player
/// but not necessarily inside their view
class Nearby : Box {
  int width() {
    return 12;
  }
  
  
  void draw(Dimension dim) {
    /// First, get the nearby Ents, sorted by closest to farthest
    auto nearbyEnts = World.nearbyEntsDistancesAt(player.coord);
    
    /// Sort the nearby Ents into directions from the player
    Ent[] nearby; /// If they're inside the view, they go in here
    Ent[][Dir] far;
    
    foreach (ent; nearbyEnts) {
      if (World.isInView(ent.coord)) {
        nearby ~= ent;
      } else {
        far[directionBetween(player.coord, ent.coord)] ~= ent;
      }
    }
    
    /// Draw the various sections now, but don't draw them if they're
    /// empty
    int y = dim.y;
    
    if (nearby.length > 0) {
      setColor(Color.Blue);
      ncs.mvprintw(y, dim.x, "NEARBY");
      ++y;
      
      foreach (ent; nearby) {
        ncs.move(y, dim.x);
        ent.sym.draw();
        ncs.mvprintw(y, dim.x + 2, toStringz(ent.name));
        ++y;
      }
    }
    
    foreach (Dir dir, ents; far) {
      setColor(Color.Blue);
      ncs.mvprintw(y, dim.x, toStringz(directionName(dir)));
      ++y;
      
      foreach (ent; ents) {
        ncs.move(y, dim.x);
        ent.sym.draw();
        ncs.mvprintw(y, dim.x + 2, toStringz(ent.name));
        ++y;
      }
    }
  }
}


/// Displays the player's current Stats
class Stats : Box {
  void draw(Dimension dim) {
    int y = dim.y;
    
    setColor(Color.Text);
    ncs.mvprintw(y, dim.x, "HP: ");
    player.hp.draw();
    ++y;
    
    setColor(Color.Text);
    ncs.mvprintw(y, dim.x, "SP: ");
    player.sp.draw();
    ++y;
    
    setColor(Color.Text);
    ncs.mvprintw(y, dim.x, "Thirst: ");
    player.thirst.draw();
    ++y;
    
    setColor(Color.Text);
    ncs.mvprintw(y, dim.x, "Hunger: ");
    player.hunger.draw();
    ++y;
  }
}