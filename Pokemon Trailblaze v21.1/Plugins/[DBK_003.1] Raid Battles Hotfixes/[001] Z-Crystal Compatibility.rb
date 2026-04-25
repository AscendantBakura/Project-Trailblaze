#===============================================================================
# Z-Crystal Compatibility Fix
# Adds hasZCrystal? method when Z-Power plugin is not installed
#===============================================================================

# Check if Z-Power plugin is installed
z_power_installed = PluginManager.installed?("[DBK] Z-Power") rescue false

if !z_power_installed
  # Add stub method to Battle::Battler
  if defined?(Battle::Battler) && !Battle::Battler.method_defined?(:hasZCrystal?)
    class Battle::Battler
      def hasZCrystal?
        return false
      end
    end
  end
  
  # Also add to Pokemon class if needed
  if defined?(Pokemon) && !Pokemon.method_defined?(:hasZCrystal?)
    class Pokemon
      def hasZCrystal?
        return false
      end
    end
  end
  
  puts "[Raid Hotfix] Z-Crystal compatibility stubs loaded (Z-Power not installed)"
end