#===============================================================================
# New data for Wonder Launcher items.
#===============================================================================
module GameData
  class Item
    attr_reader :launcher_points, :launcher_use
    
    #---------------------------------------------------------------------------
    # Wonder Launcher schema.
    #---------------------------------------------------------------------------
    SCHEMA["LauncherPoints"] = [:launcher_points, "u"]
    SCHEMA["LauncherUse"]    = [:launcher_use,    "e", {"OnPokemon" => 1, "OnMove"   => 2,
                                                        "OnBattler" => 3, "OnFoe"    => 4, 
                                                        "Direct"    => 5, "OnTarget" => 6}]
	  
    #---------------------------------------------------------------------------
    # Aliased for Wonder Launcher properties.
    #---------------------------------------------------------------------------
    Item.singleton_class.alias_method :launcher_editor_properties, :editor_properties
    def self.editor_properties
      properties = self.launcher_editor_properties
      launcher_use_array = [_INTL("Can't use with the Wonder Launcher.")]
      self.schema["LauncherUse"][2].each { |key, value| launcher_use_array[value] = key if !launcher_use_array[value] }
      properties.concat([
        ["LauncherPoints", LimitProperty.new(Settings::WONDER_LAUNCHER_MAX_POINTS), _INTL("Points required to use this item via Wonder Launcher.")],
        ["LauncherUse",    EnumProperty.new(launcher_use_array),                    _INTL("How this item can be used with the Wonder Launcher.")]
      ])
      return properties
    end
    
    alias launcher_get_property_for_PBS get_property_for_PBS
    def get_property_for_PBS(key)
      ret = launcher_get_property_for_PBS(key)
      case key
      when "LauncherPoints", "LauncherUse"
        ret = nil if ret == 0
      end
      return ret
    end
	
    alias launcher_initialize initialize
    def initialize(hash)
      launcher_initialize(hash)
      @launcher_points = hash[:launcher_points] || 0
      @launcher_use    = hash[:launcher_use]    || @battle_use
    end
    
    #---------------------------------------------------------------------------
    # Aliased for bag display properties of Wonder Launcher items.
    #---------------------------------------------------------------------------
    alias launcher_consumed_after_use? consumed_after_use?
    def consumed_after_use?
      return false if $game_temp.wonder_launcher_mode && is_launcher_item?
      return launcher_consumed_after_use?
    end
	
    alias launcher_show_quantity? show_quantity?
    def show_quantity?
      return false if $game_temp.wonder_launcher_mode && is_launcher_item?
      return launcher_show_quantity?
    end
    
    #---------------------------------------------------------------------------
    # Used to determine if item is usable via Wonder Launcher.
    #---------------------------------------------------------------------------
    def is_launcher_item?
      return @launcher_points && @launcher_points > 0
    end
    
    #---------------------------------------------------------------------------
    # Used for compiling an array of all Wonder Launcher-compatible items.
    #---------------------------------------------------------------------------
    def self.get_launcher_items
	  array = []
      xitems = [
        :XATTACK, 
        :XDEFENSE, :XDEFEND, 
        :XSPATK, :XSPECIAL, 
        :XSPDEF, 
        :XSPEED, 
        :XACCURACY
      ]
      self.each do |item|
        next if !item.is_launcher_item? || item.launcher_use <= 0
        next if Settings::X_STAT_ITEMS_RAISE_BY_TWO_STAGES && xitems.include?(item.id)
        array.push(item.id)
      end
      return array
    end
  end
end

#-------------------------------------------------------------------------------
# Adds a new target type to be used by certain Wonder Launcher items.
#-------------------------------------------------------------------------------
GameData::Target.register({
  :id          => :UserOrOther,
  :name        => _INTL("User or Other"),
  :num_targets => 1,
  :targets_foe => true,
  :long_range  => true
})