#===============================================================================
# Fix for Raid Counters Persisting Between Battles
#===============================================================================
# Bug: Raid hash persists between battles, causing counters to carry over
# Root Cause: @raidRules hash is not being cleared when raid battle ends
# Impact: Next raid starts with old counters, causing instant failure
# Solution: Completely clear raid hash and all related state on battle end
#===============================================================================

#===============================================================================
# Fix 1: Clear entire raid hash when battle ends
#===============================================================================
class Battle
  alias raid_counter_pbEndOfBattle pbEndOfBattle
  
  def pbEndOfBattle
    # End-of-battle handlers still need rank, rewards and capture settings.
    raid_counter_pbEndOfBattle
  ensure
    if @raidRules && !@raidRules.empty?
      @raidRules = {}
      @raid_turnCount = nil if defined?(@raid_turnCount)
      @raid_koCount = nil if defined?(@raid_koCount)
      @raidBattle = nil if defined?(@raidBattle)
    end
  end
end

#===============================================================================
# Fix 2: Safety check - prevent starting raid with existing counters
#===============================================================================
class Battle
  alias raid_counter_pbStartBattle pbStartBattle if method_defined?(:pbStartBattle)
  
  def pbStartBattle
    # Before battle starts, double-check raid state is clean
    if raidBattle? && @raidRules
      # Keep configured limits; only the per-battle round markers are stale.
      @raidRules.delete(:raid_turnCount)
      @raidRules.delete(:raid_koCount)
    end
    
    raid_counter_pbStartBattle if defined?(raid_counter_pbStartBattle)
  end
end