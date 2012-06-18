/// Used to dynamically lay out the ui
module wyld.core.layout;

import wyld.core.common;

import alg = std.algorithm;
import ncs = ncs.ncurses;
import std.string: toStringz;


/// The building block of the ui layout
abstract class Box {
  /// Minimum width
  int width() {
    return 0;
  }
  
  /// Minimum height
  int height() {
    return 0;
  } 
  
  /// This draws the box inside the given dimensions
  void draw(Dimension);
  
  /// Stores information on where a Box gets drawn
  static struct Dimension {
    int x, y;   /// Top-left corner coordinates
    int width, height;  /// Based off top-left corner
    
    /// This is the location of the bottom-right corner
    int x2() const {
      return x + width - 1;
    }
    
    
    /// ditto
    int y2() const {
      return y + height - 1;
    }
    
    
    /// This paints the space inside this dimension using ncurses
    void fill() const {
      for (int cy = y; cy <= y2; ++cy) {
        int xCopy = x;  /// move() cannot take a const, so we must copy x
        ncs.move(cy, xCopy);
        
        for (int cx = x; cx <= x2; ++cx) {
          ncs.addch(' ');
        }
      }
    }
  }
  
  
  /// A container of boxes
  static interface Container {
    /// Try to append the given child
    /// Return: false if there was no room/not allowed to add Box
    bool addChild(Box);
    
    /// Removes all children from this container
    void clearChildren();
  }
}


/// A simple vertical or horizontal line to separate boxes
class Separator : Box {
  /// If this separator line is horizontal
  bool isHorizontal = true;
  /// If this separator will draw itself opaque
  bool isVisible = false;
  /// The optional text to display on the separator
  string title;
  
  this(bool isHorizontal, bool isVisible = false, string title = "") {
    this.isHorizontal = isHorizontal;
    this.isVisible = isVisible;
    this.title = title;
  }
  

  int width() {
    return 1;
  }
  
  int height() {
    return 1;
  }
  
  
  void draw(Dimension dim) {
    if (isVisible) {
      setColor(Color.Border);
      dim.fill(); /// This effectively fills in the line regardless of orientation
      
      ncs.move(dim.y, dim.x);
      
      if (isHorizontal) {
        ncs.printw(toStringz(title));
      } else {
        /// If we are vertical, print the title one character at a time
        foreach (int i, ch; title) {
          ncs.move(dim.y + i, dim.x);
          ncs.addch(ch);
        }
      }
    }
  }
}


/// A simple container that stacks children next to each other either
/// vertically or horizontally
class List : Box, Box.Container {
  bool isHorizontal;
  bool isReverse;
  
  private Box[] children;
  
  this(bool isHorizontal, bool isReverse, Box[] children = []) {
    this.isHorizontal = isHorizontal;
    this.isReverse = isReverse;
    this.children = children;
  }
  
  
  int width() {
    if (isHorizontal) {
      /// The sum of childrens' widths
      return alg.reduce!("a + b")(alg.map!("a.width")(children));
    } else {
      /// The biggest width of all children
      return alg.reduce!(alg.max)(alg.map!("a.width")(children));
    }
  }
  
  int height() {
    if (isHorizontal) {
      /// The biggest height of all children
      return alg.reduce!(alg.max)(alg.map!("a.height")(children));
    } else {
      /// The sum of childrens' heights
      return alg.reduce!("a + b")(alg.map!("a.height")(children));
    }
  }
  
  
  void draw(Box.Dimension dim) {
    if (isHorizontal) {
      int x = isReverse ? dim.x2 : dim.x; /// Start on one side of the dimension
      
      for (int i = 0; i < children.length - 1; ++i) {
        auto box = children[i];
        
        /// If going reverse, we must go farther to where the box will actually start
        if (isReverse) x -= box.width - 1;
        
        box.draw(Box.Dimension(x, dim.y, box.width, dim.height));
        
        if (!isReverse) x += box.width;
        else --x;
      }
      
      /// Now draw the last child with all the remaining width
      int remainingWidth = (isReverse ? x - dim.x : dim.x2 - x) + 1;
      
      if (isReverse) x = dim.x;
      children[$-1].
        draw(Box.Dimension(x, dim.y, remainingWidth, dim.height));
    } else {
      int y = isReverse ? dim.y2 : dim.y; /// Start on one side of the dimension
      
      for (int i = 0; i < children.length - 1; ++i) {
        auto box = children[i];
        
        /// If going reverse, we must go farther to where the box will actually start
        if (isReverse) y -= box.height - 1;
        
        box.draw(Box.Dimension(dim.x, y, dim.width, box.height));
        
        if (!isReverse) y += box.height;
        else --y;
      }
      
      /// Now draw the last child with all the remaining height
      int remainingHeight = (isReverse ? y - dim.y : dim.y2 - y) + 1;
      
      if (isReverse) y = dim.y;
      children[$-1].
        draw(Box.Dimension(dim.x, y, dim.width, remainingHeight));
    }
  }
  
  
  bool addChild(Box child) {
    children ~= child;
    return true;
  }
  
  
  void clearChildren() {
    children = [];
  }
}