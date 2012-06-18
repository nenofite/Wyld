/// The concrete UI for the game
///
/// This is the concrete code, whereas the code in wyld.core.menu and
/// wyld.core.layout is the abstract stuff forming the base of the 
/// code in here.
module wyld.ui;

import wyld.core.common;
import wyld.core.ent;
import wyld.core.layout;
import wyld.core.menu;
import wyld.core.world;
import wyld.main;

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
      super(
        new List(false, false, [
          new TimeBar(),
          cast(Box) new List(true, false, [
            new List(false, false, [
              new WorldView(),
              cast(Box) new OnGround()
            ]),
            new Separator(false),
            new List(false, false, [
              new Minimap(),
              cast(Box) new Nearby()
            ]),
            cast(Box) new Stats()
          ])
        ])
      );
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
        player.move(coordFromDirection(dir));
        //menu.updateWorld();
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
    if (world.time.isDay) {
      if (world.time.isDawn || world.time.isDusk) {
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
    int sun = cast(int) (world.time.sunPosition * dim.width);
    int moon = cast(int) (world.time.moonPosition * dim.width);
    
    ncs.mvaddch(dim.y, dim.x + moon, 'C');
    
    if (world.time.isDay) {
      ncs.move(dim.y, dim.x + sun);
      Sym('O', Color.YellowBg).draw();
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
    foreach (ent; world.entsAt(player.coord)) {
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
    auto nearbyEnts = world.nearbyEntsDistances(player);
    
    /// Sort the nearby Ents into directions from the player
    Ent[] nearby; /// If they're inside the view, they go in here
    Ent[][Direction] far;
    
    foreach (ent; nearbyEnts) {
      if (world.isInView(ent.coord)) {
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
    
    foreach (Direction dir, ents; far) {
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
    player.hp.drawBar();
    ++y;
    
    setColor(Color.Text);
    ncs.mvprintw(y, dim.x, "SP: ");
    player.sp.drawBar();
    ++y;
    
    setColor(Color.Text);
    ncs.mvprintw(y, dim.x, "Thirst: ");
    player.thirst.drawBar();
    ++y;
    
    setColor(Color.Text);
    ncs.mvprintw(y, dim.x, "Hunger: ");
    player.hunger.drawBar();
    ++y;
  }
}


/// Displays the world from the player's viewpoint
class WorldView : Box {
  int width() {
    return player.viewRadius * 2 + 1;
  }
  
  int height() {
    return player.viewRadius * 2 + 1;
  }
  
  
  void draw(Dimension dim) {
    /// Calculate the in-world coordinates of the top-left corner of
    /// the view
    auto corner = Coord(player.coord.x - player.viewRadius, 
                        player.coord.y - player.viewRadius);
        
    /// First do all the dense overlaying
    for (int y = 0; y < height; ++y) {
      ncs.move(dim.y + y, dim.x);
      
      for (int x = 0; x < width; ++x) {
        /// Calculate the in-world coordinate
        auto worldCoord = Coord(x, y) + corner;
        
        Sym sym = Sym(' ', Color.Text);
        
        if (world.staticGrid.isInside(worldCoord)) {
          /// Start the sym as the terrain and static Ents at the 
          /// current coord
          sym = baseDense(worldCoord);
          
          /// Go through the screen stack and let all OverlayScreens
          /// submit to the Sym
          foreach (screen; menu.stack) {
            auto overlay = cast(Overlay) screen;
            
            if (overlay !is null) {
              overlay.dense(worldCoord, sym);
            }
          }
        }
        
        sym.draw();
      }
    }
    
    /// Next draw all the dynamic Ents
    foreach (ent; world.dynamicEnts) {
      /// Convert the coordinate from a world coordinate to a
      /// screen coordinate
      auto screenCoord = ent.coord - corner;
      
      /// Make sure the coord is inside the view before drawing it
      if (screenCoord.x >= dim.x && screenCoord.x <= dim.x2 &&
          screenCoord.y >= dim.y && screenCoord.y <= dim.y2) {
        ncs.move(screenCoord.y + dim.y, screenCoord.x + dim.x);
        ent.sym.draw();
      }
    }
    
    /// Then go through the stack and draw all the sparse CoordSyms
    foreach (screen; menu.stack) {
      auto overlay = cast(Overlay) screen;
      
      if (overlay !is null) {
        foreach (coordSym; overlay.sparse) {
          /// Convert the coordinate from a world coordinate to a
          /// screen coordinate
          auto screenCoord = coordSym.coord - corner;
          
          /// Make sure the coord is inside the view before drawing it
          if (screenCoord.x >= dim.x && screenCoord.x <= dim.x2 &&
              screenCoord.y >= dim.y && screenCoord.y <= dim.y2) {
            ncs.move(coordSym.coord.y, coordSym.coord.x);
            coordSym.sym.draw();
          }
        }
      }
    }
  }
  
  
  /// Gets the Sym for the current coord, taking terrain, static ents,
  /// and tracks into account
  Sym baseDense(Coord coord) {
    auto stat = world.staticGrid.at(coord);
    
    /// If there are tracks here and it is their turn to blink, return
    /// their Sym
    if (stat.tracks.ent !is null) {
      if (menu.ticks % 10 == stat.tracks.relativeAge % 10) {
        return stat.tracks.sym;
      }
    }
    
    /// If there are static Ents, return the Sym of the one on top
    if (stat.ents.length > 0) {
      return stat.ents[$-1].sym;
    } else {
      /// Otherwise, return the terrain's Sym
      return stat.terrain.sym;
    }
  }
  
  
  /// Draws on the WorldView
  static interface Overlay {
    /// This gets called on every Coord in the player's view
    ///
    /// Change 'sym' in order to draw something there, otherwise leave
    /// 'sym' the same to show the overlay beneath this
    ///
    /// Params:
    ///   coord = the world coordinate being drawn (*not* the view
    ///           coordinate)
    ///   sym = a mutable reference to the Sym to be drawn at the
    ///         location
    void dense(Coord coord, ref Sym sym);
    
    /// This draws a few sparse Syms
    ///
    /// This is usefel for things that may not be in the view and that
    /// are sparse across the map, such as Ents or location markers
    CoordSym[] sparse();
  }
}


class Minimap : Box {
  /// The radius of the view around the player
  ///
  /// This technically isn't the radius, because it doesn't count the
  /// player's square.  This is actually one less than the radius.
  immutable int viewRadius = 5;
  
  int width() {
    return viewRadius * 2 + 1;
  }
  
  int height() {
    return viewRadius * 2 + 1;
  }
  
  
  void draw(Dimension dim) {
    /// Calculate where the player is on the map
    auto playerCoord = world.mapCoord(player.coord);
  
    /// Calculate the in-world coordinates of the top-left corner of
    /// the view
    auto corner = playerCoord - viewRadius;
  
    for (int y = 0; y < height; ++y) {
      ncs.move(dim.y + y, dim.x);
    
      for (int x = 0; x < width; ++x) {
        /// Calculate the in-world coordinates of the current screen
        /// coordinate
        auto mapCoord = Coord(x, y) + corner;
        
        if (world.map.isInside(mapCoord)) {
          geoSym(world.map.at(mapCoord).geo).draw();
          
          world.map.at(mapCoord).isDiscovered = true;
        } else {
          ncs.addch(' ');
        }
      }
    }
    
    /// Blink the player's position over the minimap
    if (menu.ticks % 1000 < 500) {
      ncs.move(dim.y + viewRadius,
               dim.x + viewRadius);
      Sym('X', Color.Text).draw();
    }
  }
}