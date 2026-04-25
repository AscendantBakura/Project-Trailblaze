#===============================================================================
# Boss HP Reset After Capture Fix
#===============================================================================
# Bug: When a raid boss is captured, its HP doesn't reset for the next raid
# Root Cause: Pokemon object retains HP from previous raid battle
# Impact: Next raid starts with boss at low HP, making it too easy
# Solution: Reset boss HP to full when raid battle ends with capture
#===============================================================================

class Battle
  alias raid_hp_reset_pbEndOfBattle pbEndOfBattle
  
  def pbEndOfBattle
    # If this was a raid battle and we captured the boss, reset its HP
    if raidBattle? && @decision == 4 # 4 = Captured
      # Find the raid boss (usually index 1 in single battles)
      @battlers.each do |battler|
        next unless battler
        # Raid boss is typically the opponent's first Pokemon
        if battler.opposes?(0) && battler.pokemon
          # Reset HP to full for next encounter
          battler.pokemon.hp = battler.pokemon.totalhp
          battler.pokemon.heal_status
        end
      end
    end
    
    raid_hp_reset_pbEndOfBattle
  end
end

puts "[Raid Hotfix] Boss HP Reset After Capture loaded"
