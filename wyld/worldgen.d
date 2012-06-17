module wyld.worldgen;

import wyld.core.common;
import wyld.core.world;

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
  
  /// Make phase 3 grid, mapping the Geos into Terrain
  auto p3Grid = p2Grid.map2(
    (ref Geo geo, Coord) {
      return geoTerrain(geo);
    }
  );
  
  /// Subdivide
  for (int i = 0; i < p3Subdivisions; ++i) {
    p3Grid = subdivide(p3Grid);
  }
  
  /// Create the world's staticGrid by mapping phase 3 grid into
  /// StaticGridContents
  auto staticGrid = cast(World.StaticGrid) p3Grid.map2(
    (ref Terrain terrain, Coord) {
      return World.StaticGridContents(terrain, [], Tracks());
    }
  );
  
  /// Make the map by mapping phase 2 into MapContents
  auto map = cast(World.Map) p2Grid.map2(
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