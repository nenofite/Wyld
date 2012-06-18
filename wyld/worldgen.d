module wyld.worldgen;

import wyld.core.common;
import wyld.core.ent;
import wyld.core.world;
import wyld.ent;
import wyld.main;

import rand = std.random;


/// Randomly generate a new World
static World generateWorld(int p1Width, int p1Height, 
                      int p2Subdivisions, 
                      int p3Subdivisions) {
  /// Make the starting grid, which is empty
  auto p1Grid = new Grid!Geo(p1Width, p1Height);
  
  /// Fill in with noise
  p1Grid.map(
    (ref Geo geo, Coord) {
      auto rnd = rand.uniform(0, 10);
      
      if (rnd < 5) {
        geo = Geo.Grass;
      } else if (rnd < 7) {
        geo = Geo.Forest;
      } else if (rnd < 8) {
        geo = Geo.Rock;
      } else if (rnd < 9) {
        geo = Geo.Marsh;
      } else if (rnd < 10) {
        geo = Geo.Water;
      } else {
        assert(false);
      }
    }
  );
  
  /// Make phase 2 grid and subdivide
  auto p2Grid = p1Grid;
  
  for (int i = 0; i < p2Subdivisions; ++i) {
    p2Grid = subdivide(p2Grid);
  }
  
  /// Phase 2 grid must stay at its current size to be used for the world
  /// map, so further subdivision must to be done using another variable
  /// Make phase 3 grid so we can subdivide it further
  auto p3Grid = p2Grid;
  
  /// Subdivide
  for (int i = 0; i < p3Subdivisions; ++i) {
    p3Grid = subdivide(p3Grid);
  }
  
  /// Create the world's staticGrid by mapping phase 3 grid into
  /// StaticGridContents, and at the same time randomly pock the Terrain
  auto staticGrid = p3Grid.map2(
    (ref Geo geo, Coord coord) {
      Ent[] ents;
      
      switch (geo) {
        case Geo.Grass:
          if (rand.uniform(0, 100) != 0) {
            ents ~= new Grass(coord);
          }
          break;
          
        case Geo.Forest:
          if (rand.uniform(0, 20) != 0) {
            ents ~= new Grass(coord);
          }
          break;
          
        default:
          break;
      }
      
      auto terrain = geoTerrain(geo);
      
      terrain.repock();
      
      return World.StaticContents(terrain, ents, Tracks());
    }
  );
  
  for (int y = 0; y < staticGrid.height; y += 3) {
    for (int x = 0; x < staticGrid.width; x += 3) {
      if (p3Grid.at(Coord(x, y)) == Geo.Forest) {
        auto offset = Coord(rand.uniform(-1, 2), rand.uniform(-1, 2)),
             coord = Coord(x, y) + offset;
        
        if (staticGrid.isInside(coord)) {
          staticGrid.at(coord).ents = [new Tree(coord)];
        }
      }
    }
  }
  
  /// Make the map by mapping phase 2 into MapContents
  auto map = p2Grid.map2(
    (ref Geo geo, Coord) {
      return World.MapContents(geo, false);
    }
  );
  
  /// Finally, make and return the world
  return new World([], staticGrid, map, Time());
}
  

/// Subdivides the given grid once and randomly interpolates the values
Grid!A subdivide(A)(Grid!A old) {
  /// The new grid with the subdivided size
  auto newGrid = new Grid!A(old.width * 2 - 1, old.height * 2 - 1);

  /// First, fill in all the old values
  ///
  /// '-' is empty
  /// 'X' is filled in by this section
  /// ---
  /// X - X - X
  /// - - - - -
  /// X - X - X
  /// - - - - -
  /// X - X - X
  /// ---
  for (int y = 0; y < newGrid.height; y += 2) {
    for (int x = 0; x < newGrid.width; x += 2) {
      auto coord = Coord(x, y);
      
      newGrid.at(coord) = old.at(coord / 2);
    }
  }

  /// Next, randomly fill in the center values using their four diagonals,
  /// which are all old values
  ///
  /// '-' is empty
  /// 'O' is filled in previously
  /// 'X' is filled in by this section
  /// ---
  /// O - O - O
  /// - X - X -
  /// O - O - O
  /// - X - X -
  /// O - O - O
  /// ---
  for (int y = 1; y < newGrid.height; y += 2) {
    for (int x = 1; x < newGrid.width; x += 2) {
      A[4] options = [
        newGrid.at(Coord(x - 1, y - 1)),
        newGrid.at(Coord(x + 1, y - 1)),
        newGrid.at(Coord(x - 1, y + 1)),
        newGrid.at(Coord(x + 1, y + 1))
      ];
      
      newGrid.at(Coord(x, y)) = options[rand.uniform(0, 4)];
    }
  }
  
  /// Fill in the remaining spaces using their orthogonal (perpendicular)
  /// neighbors
  ///
  /// 'O' is filled in previously
  /// 'X' is filled in by this section
  /// ---
  /// O X O X O
  /// X O X O X
  /// O X O X O
  /// X O X O X
  /// O X O X O
  /// ---
  for (int y = 0; y < newGrid.height; ++y) {
    for (int x = y % 2 == 0 ? 1 : 0; x < newGrid.width; x += 2) {
      A[] options;
      
      if (newGrid.isInside(Coord(x, y - 1))) 
        options ~= newGrid.at(Coord(x, y - 1));
        
      if (newGrid.isInside(Coord(x + 1, y))) 
        options ~= newGrid.at(Coord(x + 1, y));
        
      if (newGrid.isInside(Coord(x, y + 1))) 
        options ~= newGrid.at(Coord(x, y + 1));
        
      if (newGrid.isInside(Coord(x - 1, y))) 
        options ~= newGrid.at(Coord(x - 1, y));
      
      newGrid.at(Coord(x, y)) = options[rand.uniform(0, options.length)];
    }
  }
  
  /// And finally, we're done
  return newGrid;
}


void placePlayer() {
  for (int tryNum = 0; tryNum < 10; ++tryNum) {
    auto coord = Coord(rand.uniform(world.staticGrid.width / 4, 
                                    world.staticGrid.width * 3 / 4), 
                       rand.uniform(world.staticGrid.height / 4, 
                                    world.staticGrid.height * 3 / 4));
    
    if (!world.isBlockingAt(coord)) {
      if (world.map.at(world.mapCoord(coord)).geo != Geo.Water) {
        player = new Player(coord);
        
        world.add(player);
        
        return;
      }
    }
  }
  
  assert(false, "Player placement took over 10 tries.  Failed.");
}


void placeDeer(int num = 20) {
  for (int i = 0; i < num; ++i) {
    for (int tryNum = 0; tryNum < 10; ++tryNum) {
      auto coord = Coord(rand.uniform(0, world.staticGrid.width), 
                         rand.uniform(0, world.staticGrid.height));
      
      if (!world.isBlockingAt(coord)) {
        world.add(new Deer(coord));
        break;
      }
    }
  }
}