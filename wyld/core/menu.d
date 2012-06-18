/// Contains code used for the user interface
module wyld.core.menu;

import wyld.core.common;
import wyld.core.layout;
import wyld.core.world;
import wyld.main;

import time = core.time;
import ncs = ncs.ncurses;

/// The menu in use, made easily accessible
Menu menu;


// TODO clarify this description
/// The main hub around which all ui is built
class Menu {
  Screen[] stack;   /// A first in, last out stack of screens to display
  /// The screen to display when the ESC key is pressed from the bottom screen
  Screen escScreen;
  /// The current draw tick, used for animation
  ///
  /// This is based off of system time -- 1 tick is a millisecond
  ///
  /// Not to be confused with world.time.ticks, which is the current
  /// world update tick
  int ticks;
  
  List ui;
  
  this(Screen[] stack, Screen escScreen) {
    this.stack = stack;
    this.escScreen = escScreen;
    
    ui = new List(true, true, [
      new MenuBox(),
      new Separator(false, false),
      new Separator(false, true),
      cast(Box) new TopUiBox()
    ]);
  }
  
  
  /// Add a screen to the top of the stack and initialize it
  void addScreen(Screen screen) {
    stack ~= screen;
    
    screen.init();
  }
  
  
  /// Remove the topmost screen off the stack
  void removeScreen() {
    stack = stack[0 .. $-1];
  }
  
  
  /// Goes down the stack to find the first non-null Ui
  Ui topUi() {
    foreach_reverse (screen; stack) {
      if (screen.ui !is null) {
        return screen.ui;
      }
    }
    assert(false, "No Screens have Ui");
  }
  
  
  /// Updates ticks to the system time and then draws the ui
  void draw() {
    ticks = cast(int) time.TickDuration.currSystemTick.msecs();
  
    auto dim = Box.Dimension(0, 0, ncs.COLS, ncs.LINES);
    dim.fill();
    ui.draw(dim);
  }
  
  
  /// This runs the ui continuously until the user quits
  void loop() {
    while (true) {
      updateWorld();
    
      draw();
    
      auto screen = stack[$-1];
      
      auto input = cast(char) ncs.getch();
      ncs.flushinp();
      
      /// The escape key
      if (input == 27) {
        if (stack.length > 1) {
          removeScreen();
        } else {
          /// If we're on the bottom screen, we must go to the Esc screen
          if (escScreen !is null)
            addScreen(escScreen);
        }
      } else {
        bool caughtKey;
        foreach (entry; screen.entries) {
          if (input == entry.key) {
            entry.select();
            caughtKey = true;
            break;
          }
        }
        if (!caughtKey) {
          caughtKey = screen.input(input);
        }
        if (!caughtKey) {
          caughtKey = topUi.input(input);
        }
        if (!caughtKey) {
          //assert(false);
        }
      }
      
      ncs.refresh();
    }
  }
  
  
  void updateWorld() {
    while (player.update !is null) {
      world.update();
      
      draw();
      
      ncs.refresh();
    }
  }
  
  
  /// A screen which can be displayed by Menu in the screen stack
  static abstract class Screen {
    string title; /// The title displayed by the screen
    Ui ui;  /// If not null, this will be displayed in the main view
    
    this(string title, Ui ui = null) {
      this.title = title;
      this.ui = ui;
    }
    
    
    /// The entries inside this screen's menu
    Entry[] entries();
    
    /// This is ran when the user presses a key when in this screen
    /// Return: false if the input key wasn't caught
    bool input(char key) {
      return false;
    }
    
    /// This gets ran once each time this screen is added to the menu stack
    ///
    /// Used mostly to reset ui
    void init() {
    }
  }
  
  
  /// This can be displayed in Menu's main view
  static class Ui {
    /// The graphic interface to display
    Box ui;
    
    this(Box ui) {
      this.ui = ui;
    }
    
    
    /// This is ran when the user presses a key that falls through to
    /// the displayed Ui
    /// Return: false if the input key wasn't caught
    bool input(char key) {
      return false;
    }
  }
  
  
  /// An entry to be displayed inside a Screen's menu
  static abstract class Entry {
    char key; /// The key to select this entry
    string title; /// The title shown for this entry
    
    this(char key, string title) {
      this.key = key;
      this.title = title;
    }
    
    
    /// This runs when the entry is selected
    void select();
  }
  
  
  /// A simple Entry that displays a subscreen upon selection
  static class SubEntry : Entry {
    /// The subscreen to be displayed
    Screen sub;
    
    this(char key, Screen sub) {
      this.sub = sub; 
      super(key, sub.title);
    }
    
    
    void select() {
      menu.addScreen(sub);
    }
  }
  
  
  static class MenuBox : Box {
    int width() {
      return 30;
    }
    
  
    void draw(Dimension dim) {
      auto topScreen = menu.stack[$-1];
      int y = dim.y;
      
      setColor(Color.Text);
      
      ncs.attron(ncs.A_BOLD);
      ncs.mvprintw(y, dim.x, toStringz(topScreen.title));
      ncs.attroff(ncs.A_BOLD);
      ++y;
      
      foreach (entry; topScreen.entries) {
        ncs.move(y, dim.x);
        
        setColor(Color.Green);
        ncs.addch(entry.key);
        ncs.addch(' ');
        
        setColor(Color.Text);
        ncs.printw(toStringz(entry.title));
        
        ++y;
      }
    }
  }
  
  
  static class TopUiBox : Box {
    int width() {
      return menu.topUi.ui.width;
    }
    
    int height() {
      return menu.topUi.ui.height;
    }
    
  
    void draw(Dimension dim) {
      menu.topUi.ui.draw(dim);
    }
  }
}


/// Displays a sequence of screens, allowing the user to progress forward
/// or go back through the screens in order
class ScreenSequence : Menu.Screen {
  Menu.Screen[] screens;  /// The ordered list of screens
  private int screenIndex;  /// The index of the current screen
  
  private Menu.Entry[] navigation; /// Menu entries used for navigating
  
  this(string title, Menu.Screen[] screens) {
    super(title);
    
    this.screens = screens;
    
    navigation = [
      new TextEntry(""),
      new TextEntry("---"),
      cast(Menu.Entry) new class() Menu.Entry {
        this() {
          super('\\', "Back");
        }
        
        void select() {
          previousScreen();
        }
      }
    ];
  }
  
  
  /// Goes back a screen
  void previousScreen() {
    --screenIndex;
    if (screenIndex < 0) {
      screenIndex = 0;
    }
  }
  
  
  Menu.Entry[] entries() {
    /// Start with the current screen's entries
    auto entries = screens[screenIndex].entries;
    
    /// If this isn't the first screen, display the 'Back' entry
    if (screenIndex != 0) entries ~= navigation;
    
    return entries;
  }
  
  bool input(char key) {
    return screens[screenIndex].input(key);
  }
}


/// A simple Entry that just displays the given text and is not interactive
class TextEntry : Menu.Entry {
  this(string title) {
    super('\0', title);
  }
  
  void select() {}
}