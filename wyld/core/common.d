/// Various types and utility functions that are used among several modules
module wyld.core.common;

import wyld.core.ent;

import math = std.math;

/// Some utility functions deal with ncurses
import ncs = ncs.ncurses;


/// A standard coordinate pair
struct Coord {
  int x, y;
  
  /// Overload binary operators to work on Coords
  ///
  /// ---
  /// auto coord = Coord(1, 4) * 2;
  /// assert(coord == Coord(2, 8);
  /// ---
  Coord opBinary(string op)(int a) {
    return Coord(mixin("x " ~ op ~ " a"), 
                 mixin("y " ~ op ~ " a"));
  }
  
  /// Overload binary operators to work on Coords
  ///
  /// ---
  /// auto coord = Coord(1, 3) + Coord(3, 7);
  /// assert(coord == Coord(4, 10));
  /// ---
  Coord opBinary(string op)(Coord a) {
    return Coord(mixin("x " ~ op ~ " a.x"), 
                 mixin("y " ~ op ~ " a.y"));
  }
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


/// A basic type of region, which includes the terrain and Ents
/// naturally present there
///
/// This is used during world generation as well as in the world map.
enum Geo {
  Rock,
  Grass,
  Forest,
  Marsh,
  Water
}


/// The eight basic directions
enum Direction {
  N,
  Ne,
  E,
  Se,
  S,
  Sw,
  W,
  Nw
}



/// Converts the given number from the numpad into a Direction
/// Parameters:
///   isKey = set to whether the given key was a numpad direction
/// Return: the represented Direction, or a nonsensical value if the given
///         key didn't represent a direction
Direction directionFromKey(char key, out bool isKey) {
  isKey = true;
  switch (key) {
    case '8':
      return Direction.N;
    case '9':
      return Direction.Ne;
    case '6':
      return Direction.E;
    case '3':
      return Direciotn.Se;
    case '2':
      return Direction.S;
    case '1':
      return Direction.Sw;
    case '4':
      return Direction.W;
    case '7':
      return Direction.Nw;
    default:
      isKey = false;
      return Direction.N;
  }
}


/// Converts the given Direction into a Coord
///
/// For example:
/// ---
/// auto coord = coordFromDirection(Direction.N);
/// assert(coord == Coord(0, -1));  /// This will pass
/// ---
Coord coordFromDirection(Direction dir) {
  switch (dir) {
    case N:
      return Coord(0, -1);
    case Ne:
      return Coord(1, -1);
    case E:
      return Coord(1, 0);
    case Se:
      return Coord(1, 1);
    case S:
      return Coord(0, 1);
    case Sw:
      return Coord(-1, 1);
    case W:
      return Coord(-1, 0);
    case Nw:
      return Coord(-1, -1);
    default:
      assert(false);
  }
}


/// Calculate the direct distance between the two Coords
int distanceBetween(Coord a, Coord b) {
  return cast(int) math.sqrt((b.x - a.x) ** 2 + (b.y - a.y) ** 2);
}


/// Calculate the direction from the first Coord to the second Coord
Direction directionBetween(Coord from, Coord to) {
  /// Calculate the angle between the two using right triangle witchcraft
  auto angle = math.atan2(cast(real) to.y - from.y, 
                          cast(real) to.x - from.x);
  
  /// Convert that into one of eight directions, which happen to align with
  /// the directions of Direction
  int octant = cast(int) math.round(angle * 4 / math.PI);
  
  /// Convert that direction into a proper Direction
  switch (octant) {
    case -2:
      return Dir.N;
      
    case -1:
      return Dir.Ne;
      
    case 0:
      return Dir.E;
      
    case 1:
      return Dir.Se;
      
    case 2:
      return Dir.S;
      
    case 3:
      return Dir.Sw;
      
    case 4:
    case -4:
      return Dir.W;
      
    case -3:
      return Dir.Nw;
      
    default:
      assert(false);
  }
}


/// The longhand name of the given direction
///
/// This gives the name as a string in all uppercase
/// For example, this assertion would pass:
/// ---
/// assert(directionName(Direction.Se) == "SOUTHEAST");
/// ---
string directionName(Direction dir) {
  switch (dir) {
    case N:
      return "NORTH";
    case Ne:
      return "NORTHEAST";
    case E:
      return "EAST";
    case Se:
      return "SOUTHEAST";
    case S:
      return "SOUTH";
    case Sw:
      return "SOUTHWEST";
    case W:
      return "WEST";
    case Nw:
      return "NORTHWEST";
    default:
      assert(false);
  }
}


/// A combination of a Coord and a Sym
struct CoordSym {
  Coord coord;
  Sym sym;
}