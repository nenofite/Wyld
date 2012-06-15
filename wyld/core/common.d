/// Various types and utility functions that are used among several modules
module wyld.core.common;

import wyld.core.ent;

/// Some utility functions deal with ncurses
import ncs = ncs.ncurses;


/// A standard coordinate pair
struct Coord {
  int x, y;
}


/// A character and a color pair, ready to be drawn
struct Sym {
  char sym;
  Color color;
  
  /// Draw this symbol at the current position in ncurses
  void draw() {
    setColor(color);
    ncs.addch(sym);
  }
}


/// An ncurses color pair
enum Color {
  Text,   /// Color used for interface text
  Border, /// Color used for interface borders
  
  Blue,   /// with a black background
  Green,  /// ditto
  Red,    /// ditto
  Yellow, /// ditto
  White,  /// ditto
  
  BlueBg,   /// with a white foreground
  YellowBg, /// ditto
  RedBg,    /// ditto
  
  YellowBBg,  /// with a black foreground
  RedBBg      /// ditto
}

/// Sets the color in ncurses to the given pair
void setColor(Color color) {
  ncs.attrset(ncs.COLOR_PAIR(color));
}


/// A utility that manages a two-dimensional array of Ts
class Grid(T) {
  private T[][] grid;
  
  /// Makes an empty Grid with the given dimensions
  this(int width, int height) {
    grid = new T[][](width, height);
  }
  
  
  /// Returns a reference to the given coordinate of the grid
  ref T at(Coord coord) {
    assert(isInside(coord));
    return grid[coord.x][coord.y];
  }
  
  
  /// Checks if the given coord is within the grid's dimensions
  bool isInside(Coord coord) const {
    return (coord.x >= 0) && (coord.x < width) &&
            (coord.y >= 0) && (coord.y < height);
  }
  
  
  int width() const {
    return cast(int) grid.length;
  }
  
  
  int height() const {
    return cast(int) grid[0].length;
  }
}


/// Represents the static, non Ent terrain at a location in the World
struct Terrain {
  /// The basic type of this terrain
  Type type;
  /// If true, a slightly different graphic is displayed to give texture
  bool isPocked;
  
  /// The Sym to display this terrain
  Sym sym() const {
    switch (type) {
      case Type.Dirt:
        return Sym(isPocked ? ',' : '.', Color.Yellow);
        
      case Type.Mud:
        return Sym(isPocked ? '~' : '-', Color.Yellow);
        
      case Type.Rock:
        return Sym(isPocked ? ',' : '.', Color.White);
        
      case Type.Water:
        return Sym('~', Color.Blue);
        
      default:
        assert(false);
    }
  }
  
  
  /// The Ent that is invariably at this terrain type, ie. a Water Ent
  /// is always over water terrain
  Ent ent() const {
    switch (type) {
      case Type.Water:
        //return new Water(VoidLocation, 1000);
        assert(false); // TODO
        
      default:
        return null;
    }
  }
  
  
  /// The time cost of moving over this terrain
  int movementCost() const {
    switch (type) {
      case Type.Dirt:
      case Type.Rock:
        return 50;
        
      case Type.Mud:
        return 100;
        
      case Type.Water:
        return 500;
        
      default:
        assert(false);
    }
  }
  
  
  alias Type this;
  
  enum Type {
    Dirt,
    Mud,
    Rock,
    Water
  }
}


/** A basic type of region, which includes the terrain and Ents
*   naturally present there
*
*   This is used during world generation as well as in the world map.
*/
enum Geo {
  Rock,
  Grass,
  Forest,
  Marsh,
  Water
}