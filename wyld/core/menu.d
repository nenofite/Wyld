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
  bool running;
  
  List ui;
  
  string[] messages;
  string[] newMessages;
  
  this(Screen[] stack, Screen escScreen) {
    this.stack = stack;
    this.escScreen = escScreen;
    
    ui = new List(true, true, [
      new MenuBox(),
      new Separator(false, false),
      new Separator(false, true),
      cast(Box) new List(false, true, [
        new MessageBox(),
        cast(Box) new TopUiBox()
      ])
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
    running = true;
  
    while (running) {
      updateWorld();
    
      draw();
    
      auto screen = stack[$-1];
      
      auto input = ncs.getch();
      ncs.flushinp();
      
      /// If there are more messages to be displayed
      if (newMessages.length > MessageBox.maxMessages) {
        switch (input) {
          case '\n':
            /// Enter key advances them
            messages ~= newMessages[0 .. MessageBox.maxMessages+1];
            newMessages = newMessages[MessageBox.maxMessages+1 .. $];
            
            break;
          case 27: 
            /// The Escape key clears them
            messages ~= newMessages;
            newMessages = [];
          
            break;
          default:
            break;
        }
      } else if (input == 27) { /// The Escape key
        if (stack.length > 1) {
          removeScreen();
        } else {
          /// If we're on the bottom screen, we must go to the Esc screen
          if (escScreen !is null)
            addScreen(escScreen);
        }
      /// If a key was actually pressed
      } else if (input != ncs.ERR) {
        /// Make the new messages old
        messages ~= newMessages;
        newMessages = [];
      
        bool caughtKey;
        foreach (entry; screen.entries) {
          if (cast(char) input == entry.key) {
            entry.select();
            caughtKey = true;
            break;
          }
        }
        if (!caughtKey) {
          caughtKey = screen.input(cast(char) input);
        }
        if (!caughtKey) {
          caughtKey = topUi.input(cast(char) input);
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
  
  
  /// Add a new message for the player
  void addMessage(string message) {
    newMessages ~= message;
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
        if (entry.key == '\0') {
          ncs.addch(' ');
        } else {
          ncs.addch(entry.key);
        }
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
  
  
  /// Displays messages to the player
  static class MessageBox : Box {
    /// The max lines of messages to be displayed at once
    immutable int maxMessages = 5;
  
    int height() {
      if (menu.newMessages.length > 0) {
        /// Display at most 'maxMessages' lines at a time, with a 
        /// line of padding from the ui and a line for 'more'
        return alg.min(maxMessages + 1, menu.newMessages.length) + 1;
      } else {
        return 0;
      }
    }
    
    
    void draw(Dimension dim) {
      /// How many lines of messages are being drawn
      /// Start being set to the length of newMessages
      int messagesToDraw = cast(int) menu.newMessages.length;
      /// If there are more lines
      bool isMore = false;
                                   
      /// Clip the number of lines to maxMessages
      if (messagesToDraw > maxMessages) {
        messagesToDraw = maxMessages;
        isMore = true;
      }
    
      setColor(Color.Blue);
      
      /// Display messages, skipping the first line of this Box
      /// to leave it blank, as padding
      for (int i = 0; i < messagesToDraw; ++i) {
        ncs.mvprintw(dim.y + 1 + i, dim.x, 
                     toStringz(menu.newMessages[i]));
      }
      
      /// Draw the 'more' sign at the bottom
      if (isMore) {
        setColor(Color.BlueBg);
        
        ncs.mvprintw(dim.y2, dim.x, "[MORE]");
      }
    }
  }
}


/// Displays a sequence of screens, allowing the user to progress forward
/// or go back through the screens in order
abstract class SequenceScreen : Menu.Screen {
    PageScreen[] screens;
    int index;
    
    bool locked;
    
    TextEntry spacerEntry;
    BackEntry backEntry;

    this(PageScreen[] screens) {
        super("");
        this.screens = screens;
        spacerEntry = new TextEntry("");
        backEntry = new BackEntry(this);
        update();
    }
    
    abstract string pageTitle(PageScreen page);
    
    void update() {
        screens[index].init();
        title = pageTitle(screens[index]);
    }
    
    void previousScreen() {
        screens[index].clear();
        index--;
        if (index < 0) index = 0;
        update();
    }
    
    void nextScreen() {
        index++;
        if (index >= screens.length) index = cast(int)screens.length - 1;
        update();
    }
    
    Menu.Entry[] entries() {
        return screens[index].entries() ~ naviEntries();
    }
    
    Menu.Entry[] naviEntries() {
        if (locked || index == 0) return [];
    
        return [
            spacerEntry,
            cast(Menu.Entry)backEntry
        ];
    }
    
    bool input(char key) {
        return screens[index].input(key);
    }
    
    static class BackEntry : Menu.Entry {
        SequenceScreen screen;
        
        this(SequenceScreen screen) {
            super('\\', "Back");
            this.screen = screen;
        }
        
        void select() {
            screen.previousScreen();
        }
    }
}


abstract class PageScreen : Menu.Screen {
    this(string title) {
        super(title);
    }

    void clear() {}
}


/// A simple Entry that just displays the given text and is not interactive
class TextEntry : Menu.Entry {
  this(string title) {
    super('\0', title);
  }
  
  void select() {}
}


abstract class Message {
    abstract string text();
    
    void broadcast() {
        menu.addMessage(text());
    }
}

class SimpleMessage : Message {
    string msg;
    
    this(string msg) {
        this.msg = msg;
    }
    
    string text() {
        return msg;
    }
}
