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
import wyld.ent;
import wyld.interactions;
import wyld.main;

import ncs = ncs.ncurses;
import std.string: toStringz;


/// The main UI that the player sees while playing the game
///
/// This includes the world view, time of day, player stats, etc.
///
/// Not to be confused with the main menu
class MainScreen : Menu.Screen {
  MapScreen mapScreen;
  Interact interact;
  ChooseRecipe craft;
  Skills skills;

  this() {
    super("Main", new Ui());
    
    mapScreen = new MapScreen();
    interact = new Interact();
    craft = new ChooseRecipe();
    skills = new Skills();
  }
  
  Menu.Entry[] entries() {
    return [
      new Menu.SubEntry('m', mapScreen),
      new Menu.SubEntry('i', interact),
      new Menu.SubEntry('r', craft),
      new Menu.SubEntry('k', skills),
      new Menu.SubEntry('a', new Messages())
    ];
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
        player.attackMove(coordFromDirection(dir));
      } else if (key == '5') {
        player.update = new class() Update {
          this() {
            super(Time.fromSeconds(1), [], []);
          }
          
          void apply() {
          }
        };
      } else {
        return false;
      }
      
      return true;
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
    auto nearbyEnts = player.nearbyEntsDistances();
    
    /// Sort the nearby Ents into directions from the player
    Ent[] nearby; /// If they're inside the view, they go in here
    Ent[][Direction] far;
    
    foreach (ent; nearbyEnts) {
      if (ent !is player) {
        if (world.isInView(ent.coord)) {
          nearby ~= ent;
        } else {
          far[directionBetween(player.coord, ent.coord)] ~= ent;
        }
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
    
    ++y;
    
    setColor(Color.Text);
    ncs.mvprintw(y, dim.x, "Equipped: ");
    if (player.equipped !is null) {
        setColor(Color.Blue);
        ncs.printw(toStringz(player.equipped.name));
    } else
        ncs.printw("(N/A)");
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
      auto screenCoord = ent.coord - corner + Coord(dim.x, dim.y);
      
      /// Make sure the coord is inside the view before drawing it
      if (screenCoord.x >= dim.x && screenCoord.x <= dim.x2 &&
          screenCoord.y >= dim.y && screenCoord.y <= dim.y2) {
        ncs.move(screenCoord.y, screenCoord.x);
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
          auto screenCoord = coordSym.coord - corner + Coord(dim.x, dim.y);
          
          /// Make sure the coord is inside the view before drawing it
          if (screenCoord.x >= dim.x && screenCoord.x <= dim.x2 &&
              screenCoord.y >= dim.y && screenCoord.y <= dim.y2) {
            ncs.move(screenCoord.y, screenCoord.x);
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


/// Displays a small section of the world map around the player
///
/// This is also what handles the discovery of new map tiles
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


/// Displays the world map
class MapScreen : Menu.Screen {
  /// The custom Ui
  ///
  /// This is the same as what's in 'ui', but its stored here too so that
  /// we don't have to cast it to Ui every time
  Ui mapUi;

  this() {
    super("Map");
    
    mapUi = new Ui();
    ui = mapUi;
  }
  
  
  Menu.Entry[] entries() {
    return [new CenterOnPlayer(mapUi)];
  }
  
  
  /// Recenter the map on the player every time this screen is added
  void init() {
    mapUi.centerOnPlayer();
  }


  /// A menu entry that just centers on the player
  static class CenterOnPlayer : Menu.Entry {
    Ui ui;

    this(Ui ui) {
      this.ui = ui;
      
      super('c', "Center on player");
    }
    
    void select() {
      ui.centerOnPlayer();
    }
  }
  
  
  /// Displays the actual map
  static class Ui : Menu.Ui {
    /// The coord at the center of the map
    ///
    /// By storing location by the center instead of the corner, the map
    /// will keep its general focus even when drawing dimensions change
    Coord centeredOn;
  
    this() {
        super(new Display(this));
    }
    
    
    bool input(char key) {
      bool isDirKey;
      auto dir = directionFromKey(key, isDirKey);
      
      if (isDirKey) {
        centeredOn = centeredOn + coordFromDirection(dir);
      }
      
      return isDirKey;
    }
    
    
    /// Center on the player's current location
    void centerOnPlayer() {
      centeredOn = world.mapCoord(player.coord);
    }
    
    
    /// Handles the drawing of the map
    static class Display : Box {
      /// We need a reference of this to get 'centeredOn'
      Ui ui;
      
      this(Ui ui) {
        this.ui = ui;
      }
    
    
      void draw(Dimension dim) {
        /// Calculate where the corner of the view is in map coordinates
        auto corner = ui.centeredOn - Coord(dim.width, dim.height) / 2;
        
        setColor(Color.Text);
        
        for (int y = 0; y < dim.height; ++y) {
          ncs.move(dim.y + y, dim.x);
          
          for (int x = 0; x < dim.width; ++x) {
            /// Current coordinate
            auto coord = Coord(x, y) + corner;
            
            /// If the Coord is inside the map and discovered, draw it
            if (world.map.isInside(coord)) {
              auto value = world.map.at(coord);
              
              if (value.isDiscovered) {
                geoSym(value.geo).draw();
              } else {
                ncs.attron(ncs.A_BOLD);
                Sym('#', Color.White).draw();
                ncs.attroff(ncs.A_BOLD);
              }
            } else {
              /// Still draw padding where it's outside of the map, so
              /// that the entire view doesn't get messed up
              ncs.addch(' ');
            }            
          }
        }
        
        /// Blink the player's location
        if (menu.ticks % 1000 < 500) {
          auto playerCoord = 
            world.mapCoord(player.coord) - corner + Coord(dim.x, dim.y);
            
          if (playerCoord.x >= dim.x && playerCoord.x <= dim.x2 &&
              playerCoord.y >= dim.y && playerCoord.y <= dim.y2) {
            ncs.move(playerCoord.y, playerCoord.x);
            
            Sym('X', Color.Text).draw();
          }
        }
      }
    }
  }
}


/// Player chooses items and interacts with them
class Interact : Menu.Screen {
  /// The currently selected Ents
  Ent[] selected;
  /// This is used to cull out selected Ents that are not shown   
  /// in the menu; selected Ents are added to this when displayed
  /// on the menu, and any Ents not added to this are deselected
  Ent[] newSelected;

  this() {
    super("Interact");
  }
  
  
  /// Create entries to select accessible Ents
  Menu.Entry[] items() {
    Menu.Entry[] entries;
    
    /// Reset newSelected; the Ent entries will add to it accordingly
    newSelected = [];
    
    /// Used to give each item an alphabetic key for selecting
    char key = 'a';
    
    entries ~= entSection(key, "Inventory", player.contained);
    
    entries ~= entSection(key, "On Ground", player.entsOnGround());
    
    /// Cull out any selected Ents that were not shown in the menu
    selected = newSelected;
    
    return entries;
  }
  
  
  /// The list of Interactions applicable to the selection
  Menu.Entry[] interactions() {
    Menu.Entry[] entries;
    
    /// Make an Entry for each Interaction
    foreach (interaction; player.interactions) {
      /// Check that this Interaction is applicable to all selected
      /// Ents before listing it
      bool allApplicable = true;
      
      /// Assure that all Ents are individually applicable
      foreach (ent; selected) {
        if (!interaction.isApplicable(ent)) {
          allApplicable = false;
        }
      }
      
      if (allApplicable) {
        /// If it is a Multi Interaction, make sure the selection
        /// as a whole is applicable
        auto multi = cast(Interaction.Multi) interaction;
        
        if (multi !is null) {
          if (!multi.isMultiApplicable(selected)) {
            allApplicable = false;
          }
        }
        
        /// Finally, if everything was applicable, list the Interaction
        if (allApplicable) {
          entries ~= interactionEntry(interaction);
        }
      }
    }
    
    return entries;
  }
  
  
  /// Mash together the items and the interactions into the menu
  Menu.Entry[] entries() {
    return items ~  /// Items to select
           [cast(Menu.Entry) new TextEntry("---")] ~ /// Separator
           interactions;  /// Available interactions
  }
  
  
  /// On init, clear the selection
  void init() {
    selected = [];
  }
  
  /// Creates an Entry for an Interaction, which applies it upon selection
  Menu.Entry interactionEntry(Interaction interaction) {
    return new class(this, interaction) Menu.Entry {
      Interact interact;
      Interaction interaction;
      
      this(Interact interact, Interaction interaction) {
        this.interact = interact;
        this.interaction = interaction;
        
        super(interaction.key, interaction.title);
      }
      
      
      /// When this Entry is selected, apply the Interaction
      void select() {
        /// Check if the Interaction is Single or Double, then run it accordingly
        auto single = cast(Interaction.Single) interaction;
        
        if (single !is null) {
          /// Map Interaction over each selection individually
          foreach (ent; interact.selected) {
            single.apply(ent);
            
            /// Update the world with the Interaction's changes
            menu.updateWorld();
          }
        } else {
          auto multi = cast(Interaction.Multi) interaction;
          
          assert(multi !is null, 
                 "Interaction is neither Single nor Multi");
          
          /// Run interaction on the entire selected list as a whole
          multi.apply(interact.selected);
        }
      }
    };
  }
  
  
  /// Creates a menu entry to select the given Ent
  Menu.Entry entEntry(char key, Ent ent) {
    return new class(key, ent, this) Menu.Entry {
      Ent ent;
      Interact interact;
    
      this(char key, Ent ent, Interact interact) {
        super(key, ent.name);
        
        this.ent = ent;
        this.interact = interact;
        
        /// If the Ent is selected, put square brackets around 
        /// its the title
        if (interact.selected.contains(ent)) {
          title = "[" ~ title ~ "]";
          
          if (!interact.newSelected.contains(ent)) {
            interact.newSelected ~= ent;
          }
        } else {
          title = " " ~ title;
        }
      }
      
      
      /// Toggle Ent selection when the menu entry is selected
      void select() {
        if (interact.selected.contains(ent)) {
          interact.selected.remove(ent);
        } else {
          interact.selected ~= ent;
        }
      }
    };
  }
  
  
  /// Creates a section of menu entries for the given Ent source
  ///
  /// For example, to make a section for Ents in the player's inventory
  /// or for Ents on the ground
  Menu.Entry[] entSection(ref char key, string title, Ent[] ents) {
    Menu.Entry[] entries;
    
    /// Make the title
    entries ~= new TextEntry(title ~ ":");
  
    if (ents.length > 0) {
      /// Go through each Ent and create an entry for it
      foreach (ent; ents) {
        /// Create a selectable entry for the Ent
        entries ~= entEntry(key, ent);
        
        /// Move on to the next letter in the alphabet for the key
        ++key;
      }
    } else {
      /// If this contains no Ents, show that it is empty
      entries ~= new TextEntry(" (empty)");
    }
    
    return entries;
  }
  
  
  /// Contains an Ent and whether it is currently selected
  struct EntSelect {
    Ent ent;
    bool isSelected;
    
    alias ent this;
  }
}


class Craft : SequenceScreen {
    Recipe recipe;
    
    this(Recipe recipe) {
        this.recipe = recipe;
        IngScreen[] ingScreens = new IngScreen[recipe.ingredients.length],
                    toolScreens = new IngScreen[recipe.tools.length];
        
        foreach (int i, Ingredient ing; recipe.ingredients) {
            ingScreens[i] = new IngScreen(ing, this);
        }
        
        foreach (int i, Ingredient ing; recipe.tools) {
            toolScreens[i] = new IngScreen(ing, this);
        }
        
        auto acceptScreen = new AcceptScreen(this);
        
        PageScreen[] screens = ingScreens ~ toolScreens;
        screens ~= acceptScreen;
        
        super(screens);
    }
    
    string pageTitle(PageScreen page) {
        return page.title ~ " (" ~ recipe.name ~ ")";
    }
    
    void init() {
        locked = false;
        recipe.clearIngredients();
    }
    
    bool isTaken(Ent ent) {
        foreach (Ingredient ing; recipe.ingredients) {
            if (ing.ent is ent) return true;
        }
        foreach (Ingredient ing; recipe.tools) {
            if (ing.ent is ent) return true;
        }
        
        return false;
    }
    
    bool input(char key) {
        return true;
    }
    
    static class AcceptScreen : PageScreen {
        Craft screen;
        bool crafting;
        
        this(Craft screen) {
            super(screen.recipe.name);
            this.screen = screen;
        }
        
        Menu.Entry[] entries() {
            Menu.Entry[] ret;
            
            ret ~= new TextEntry(" Ingredients:");
            foreach (Ingredient ing; screen.recipe.ingredients) {
                ret ~= new TextEntry(ing.ent.name);
            }
            
            ret ~= new TextEntry(" Tools:");
            foreach (Ingredient ing; screen.recipe.tools) {
                ret ~= new TextEntry(ing.ent.name);
            }
            
            if (!crafting) ret ~= new AcceptEntry(this);
            
            return ret;
        }
        
        static class AcceptEntry : Menu.Entry {
            AcceptScreen screen;
            
            this(AcceptScreen screen) {
                super('A', "Accept & craft");
                this.screen = screen;
            }
            
            void select() {
                player.update = new CraftUpdate(screen.screen.recipe, screen.screen);
                screen.crafting = true;
                screen.screen.locked = true;
            }
        }
    }
    
    static class IngScreen : PageScreen {
        Craft screen;
        Ingredient ingredient;
        
        this(Ingredient ingredient, Craft screen) {
            super(ingredient.name);
            this.ingredient = ingredient;
            this.screen = screen;
        }
        
        Menu.Entry[] entries() {
            char key = 'a';
            auto ret = entSection(key, "Inventory", player.contained);
            ret ~= entSection(key, "On Ground", player.entsOnGround());
            
            return ret;
        }
        
        Menu.Entry[] entSection(ref char key, string title, Ent[] ents) {
            Menu.Entry[] ret;
            ret ~= new TextEntry(title ~ ":");
            
            bool empty = true;
            foreach (Ent ent; ents) {
                if (!screen.isTaken(ent) && ingredient.canTake(ent)) {
                    ret ~= new EntEntry(key, ent, this);
                    key++;
                    empty = false;
                }
            }
            if (empty) ret ~= new TextEntry(" (none)");
            
            return ret;
        }
        
        void clear() {
            ingredient.ent = null;
        }
        
        void init() {
            ingredient.ent = null;
        }
        
        static class EntEntry : Menu.Entry {
            Ent ent;
            IngScreen screen;
            
            this(char key, Ent ent, IngScreen screen) {
                super(key, " " ~ ent.name);
                this.ent = ent;
                this.screen = screen;
            }
            
            void select() {
                screen.ingredient.ent = ent;
                screen.screen.nextScreen();
            }
        }
    }
    
    static class CraftUpdate : Update {
        Recipe recipe;
        Craft screen;
        
        this(Recipe recipe, Craft screen) {
            super(recipe.time, [], []);
            this.recipe = recipe;
            this.screen = screen;
        }
        
        void apply() {
            auto result = recipe.craft();
            
            foreach (Ingredient ing; recipe.ingredients) {
                if (ing.ent.container is player) player.contained.remove(ing.ent);
                else world.remove(ing.ent);
            }
            
            result.addTo(player);
            
            menu.removeScreen();
        }
    }
}


class ChooseRecipe : Menu.Screen {
    this() {
        super("Craft");
    }
    
    Menu.Entry[] entries() {
        RecipeEntry[] ret = new RecipeEntry[player.recipes.length];
        
        char key = 'a';
        foreach (int i, Recipe rec; player.recipes) {
            ret[i] = new RecipeEntry(key, rec);
            key++;
        }
        
        return ret;
    }
    
    static class RecipeEntry : Menu.Entry {
        Recipe recipe;
        
        this(char key, Recipe recipe) {
            super(key, recipe.name);
            this.recipe = recipe;
        }
        
        void select() {
            menu.addScreen(new Craft(recipe));
        }
    }
}


/// Displays all previously seen messages
class Messages : Menu.Screen {
  /// The index of the latest message displayed on screen
  int messageIndex;

  this() {
    super("Messages", new Ui(this));
  }
  
  
  Menu.Entry[] entries() {
    return [];
  }
  
  
  /// Reset to showing the latest message
  void init() {
    messageIndex = cast(int) menu.messages.length - 1;
  }
  
  
  static class Ui : Menu.Ui {
    Messages msgs;
  
    this(Messages msgs) {
      super(new MsgBox(msgs));
      
      this.msgs = msgs;
    }
    
    
    /// Use 8 and 2 to scroll
    bool input(char key) {
      switch (key) {
        case '8':
          --msgs.messageIndex;
          break;
        case '2':
          ++msgs.messageIndex;
          break;
        default:
          return false;
      }
      
      /// Clip the message index
      if (msgs.messageIndex < 0) {
        msgs.messageIndex = 0;
      } else if (msgs.messageIndex >= menu.messages.length) {
        msgs.messageIndex = cast(int) menu.messages.length - 1;
      }
      
      return true;
    }
    
    
    /// The display
    static class MsgBox : Box {
      Messages msgs;
    
      this(Messages msgs) {
        this.msgs = msgs;
      }
    
      void draw(Dimension dim) {
        int i = msgs.messageIndex - dim.height + 1;
        
        setColor(Color.Text);
        
        /// Go through each line and draw that message
        for (int y = 0; y < dim.height; ++y) {
          if (i >= 0) {
            ncs.mvprintw(dim.y + y, dim.x,
                         toStringz(menu.messages[i]));
          }
          
          ++i;
        }
      }
    }
  }
}

class EscapeScreen : Menu.Screen {
    this() {
        super("Main Menu");
    }
    
    Menu.Entry[] entries() {
        return [
            new class Menu.Entry {
                this() {
                    super('Q', "Quit");
                }
                
                void select() {
                    menu.running = false;
                }
            }
        ];
    }
}

class Skills : Menu.Screen {
    Jump jump;
    SleepScreen sleep;

    this() {
        super("Skills");
        jump = new Jump();
        sleep = new SleepScreen();
    }
    
    Menu.Entry[] entries() {
        return [
            new Menu.SubEntry('j', jump),
            new Menu.SubEntry('s', sleep)
        ];
    }
}

class SleepScreen : Menu.Screen {
    UntilDawn untilDawn;
    OneHour oneHour;
    
    Sleep update;

    this() {
        super("Sleep");
        
        untilDawn = new UntilDawn(this);
        oneHour = new OneHour(this);
    }
    
    Menu.Entry[] entries() {
        return [untilDawn, cast(Menu.Entry)oneHour];
    }
    
    static class UntilDawn : Menu.Entry {
        SleepScreen screen;
    
        this(SleepScreen screen) {
            this.screen = screen;
            super('D', "Until Dawn");
        }
        
        void select() {
            auto upd = Sleep.untilDawn(player);
            player.update = upd;
            menu.addScreen(new WaitScreen(upd));
        }
    }
    
    static class OneHour : Menu.Entry {
        SleepScreen screen;
    
        this(SleepScreen screen) {
            this.screen = screen;
            super('H', "For 1 Hour");
        }
        
        void select() {
            auto upd = Sleep.forTime(Time.fromHours(1), player);
            player.update = upd;
            menu.addScreen(new WaitScreen(upd));
        }
    }
    
    static class WaitScreen : Menu.Screen {
        Sleep update;
        
        TimeEntry time;
    
        this(Sleep update) {
            this.update = update;
            time = new TimeEntry(this);
            super("Sleeping...");
        }
        
        Menu.Entry[] entries() {
            time.updateTitle();
            return [time];
        }
        
        static class TimeEntry : Menu.Entry {
            WaitScreen screen;
            
            this(WaitScreen screen) {
                this.screen = screen;
                super('\0', "");
                updateTitle();
            }
            
            void updateTitle() {
                auto hours = screen.update.timeRemaining() / Time.fromMinutes(1);
                title = format("%d minutes remaining", hours);
            }
            
            void select() {}
        }
    }
}

class Jump : Menu.Screen, WorldView.Overlay {
    Coord marker;

    this() {
        super("Jump");
    }
    
    Menu.Entry[] entries() {
        return [];
    }
    
    void init() {
        marker = player.coord;
    }
    
    bool input(char key) {
        if (key == '\n') {
            if (!world.isBlockingAt(marker)) {
                player.update = new JumpTo(marker, player);
                menu.removeScreen();
            } else {
                menu.addMessage("There is something blocking you from jumping there.");
            }
        } else {
            bool isDir;
            auto dir = directionFromKey(key, isDir);
            if (isDir) {
                auto newMarker = marker + coordFromDirection(dir);
                if (distanceBetween(newMarker, player.coord) <= player.jumpRadius &&
                    !world.isAirBlockingAt(newMarker))
                    marker = newMarker;
            }
        }
        return true;
    }
    
    void dense(Coord coord, ref Sym sym) {
        auto dist = distanceBetween(coord, player.coord);
        if (dist == player.jumpRadius + 1) {
            sym.color = Color.Border;
        } else if (dist <= player.jumpRadius) {
            if (world.isAirBlockingAt(coord)) {
                sym.color = Color.Border;
            } else if (world.isBlockingAt(coord)) {
                sym.color = Color.RedBBg;
            }
        }
    }
    
    CoordSym[] sparse() {
        return [CoordSym(marker, Sym('X', Color.Yellow))];
    }
}
