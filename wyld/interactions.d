/// This contains game-specific Interaction implementations
module wyld.interactions;

import wyld.core.ent;
import wyld.main;

import alg = std.algorithm;
import math = std.math;


/// Let the player drink fluids to alleviate thirst
class Drink : Interaction.Single {
  this() {
    super('q', "Drink");
  }
  
  
  /// Any Ent can be drunk as long as it's a fluid
  bool isApplicable(Ent ent) {
    return ent.tags.isFluid;
  }
  
  
  /// Make the player drink it
  void apply(Ent ent) {
    /// The max amount the player would want to drink given their thirst
    int maxStatAmount = player.thirst.max - player.thirst,
    /// The max amount available to drink from the Ent
        maxDrinkAmount = cast(int) (ent.tags.size * ent.tags.drinkCo);
    /// The smaller of the two (the amount that will actually get drunk)
    int drinkAmount = alg.min(maxStatAmount, maxDrinkAmount);
    
    /// Remove the amount's corresponding volume from the Ent
    ent.tags.size -= math.ceil(drinkAmount / ent.tags.drinkCo);
    
    /// Add the amount to the player's thirst (as in, make them less thirsty)
    player.thirst += drinkAmount;
  }
}