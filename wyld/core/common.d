/// Various types and utility functions that are used among several modules
module wyld.core.common;

import wyld.core.ent;
import wyld.ent;

import math = std.math;

/// Some utility functions deal with ncurses
import ncs = ncs.ncurses;
import rand = std.random;


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
    //assert(isInside(coord));
    if (!isInside(coord)) {
      int* b;
      *b = 5;
    }
    return grid[coord.x][coord.y];
  }
  
  
  /// Maps the given function over the elements of the grid
  void map(void delegate(ref T, Coord) f) {
    for (int x = 0; x < width; ++x) {
      for (int y = 0; y < height; ++y) {
        auto coord = Coord(x, y);
        
        f(at(coord), coord);
      }
    }
  }
  
  
  /// Maps the given function over the elements of the grid, while
  /// constructing a new grid of a different type based on what it
  /// returns
  ///
  /// ---
  /// Grid!int a; /// Assuming this has already been 
  ///             ///constructed and filled in...
  ///
  /// /// This sets b to a grid full of the ints converted to strings,
  /// /// while incrementing all the values of a at the same time.
  /// Grid!string b = a.map2(
  ///   (ref int val, Coord) {
  ///     string name = [cast(char) val] ~ " loves pie.";
  ///     
  ///     ++val;
  ///     
  ///     return name;
  ///   }
  /// );
  /// ---
  Grid!A map2(A)(A delegate(ref T, Coord) f) {
    auto newGrid = new Grid!A(width, height);
    
    for (int x = 0; x < width; ++x) {
      for (int y = 0; y < height; ++y) {
        auto coord = Coord(x, y);
        
        newGrid.at(coord) = f(at(coord), coord);
      }
    }
    
    return newGrid;
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
  
  private static Ent waterEnt;
  
  static this() {
    waterEnt = new Water(-1);
  }
  
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
  Ent ent() {
    switch (type) {
      case Type.Water:
        waterEnt.tags.size = 10_000;
        return waterEnt;
        
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
  
  
  /// If the terrain blocks movement entirely
  bool isBlocking() const {
    switch (type) {
      case Type.Water:
        return true;
      default:
        return false;
    }
  }
  
  
  /// Uses the standard probability for terrain being pocked to randomly
  /// set isPocked for this Terrain
  void repock() {
    isPocked = rand.uniform(0, 5) == 0;
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


/// The Sym corresponding to the given Geo
Sym geoSym(Geo geo) {
  switch (geo) {
    case Geo.Rock:
      return Sym('-', Color.White);
    case Geo.Grass:
      return Sym('"', Color.Green);
    case Geo.Forest:
      return Sym('t', Color.Green);
    case Geo.Marsh:
      return Sym('~', Color.Yellow);
    case Geo.Water:
      return Sym('~', Color.Blue);
    default:
      assert(false);
  }
}


/// Returns the Terrain corresponding to the given Geo
Terrain geoTerrain(Geo geo) {
  switch (geo) {
    case Geo.Rock:
      auto type = Terrain.Rock;
      
      if (rand.uniform(0, 20) == 0) {
        type = Terrain.Dirt;
      }
      
      return Terrain(type);
      
    case Geo.Grass:
    case Geo.Forest:
      return Terrain(Terrain.Dirt);
      
    case Geo.Marsh:
      return Terrain(Terrain.Mud);
      
    case Geo.Water:
      return Terrain(Terrain.Water);
      
    default:
      assert(false);
  }
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
      return Direction.Se;
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
    case Direction.N:
      return Coord(0, -1);
    case Direction.Ne:
      return Coord(1, -1);
    case Direction.E:
      return Coord(1, 0);
    case Direction.Se:
      return Coord(1, 1);
    case Direction.S:
      return Coord(0, 1);
    case Direction.Sw:
      return Coord(-1, 1);
    case Direction.W:
      return Coord(-1, 0);
    case Direction.Nw:
      return Coord(-1, -1);
    default:
      assert(false);
  }
}


/// Calculate the direct distance between the two Coords
int distanceBetween(Coord a, Coord b) {
  return cast(int) math.sqrt((b.x - a.x) ^^ 2 + (b.y - a.y) ^^ 2);
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
      return Direction.N;
      
    case -1:
      return Direction.Ne;
      
    case 0:
      return Direction.E;
      
    case 1:
      return Direction.Se;
      
    case 2:
      return Direction.S;
      
    case 3:
      return Direction.Sw;
      
    case 4:
    case -4:
      return Direction.W;
      
    case -3:
      return Direction.Nw;
      
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
    case Direction.N:
      return "NORTH";
    case Direction.Ne:
      return "NORTHEAST";
    case Direction.E:
      return "EAST";
    case Direction.Se:
      return "SOUTHEAST";
    case Direction.S:
      return "SOUTH";
    case Direction.Sw:
      return "SOUTHWEST";
    case Direction.W:
      return "WEST";
    case Direction.Nw:
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


/// Removes the first occurence of the given item from the list
void remove(T)(ref T[] list, T item) {
  T[] newList = new T[](list.length - 1);
  
  bool found;
  foreach (i, a; list) {
    if (!found && a is item) {
      found = true;
    } else if (found) {
      newList[i-1] = a;
    } else {
      newList[i] = a;
    }
  }
  
  assert(found, "Element not found in list.");
  
  list = newList;
}