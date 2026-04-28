#====================================================================================
#  DO NOT MAKE EDITS HERE
#====================================================================================
module GameData
	class ContestType
		attr_reader :id
		attr_reader :real_name
		attr_reader :long_name
		attr_reader :icon_index
	  
		DATA = {}

		extend ClassMethodsSymbols
		include InstanceMethods

		def self.load; end
		def self.save; end

		def initialize(hash)
			@id           = hash[:id]
			@real_name    = hash[:name]         || "Unnamed"
			@long_name    = hash[:long_name]    || @real_name
			@icon_index   = hash[:icon_index]   || 0
		end
		
		def name
			return _INTL(@real_name)
		end
	end
end

#====================================================================================
#============================= Contest Type Definitions =============================
#====================================================================================
GameData::ContestType.register({
  :id           => :COOL,
  :name         => _INTL("Cool"),
  :long_name    => _INTL("Coolness"),
  :icon_index   => 0
})

GameData::ContestType.register({
  :id           => :BEAUTY,
  :name         => _INTL("Beauty"),
  :long_name    => _INTL("Beauty"),
  :icon_index   => 1
})

GameData::ContestType.register({
  :id           => :CUTE,
  :name         => _INTL("Cute"),
  :long_name    => _INTL("Cuteness"),
  :icon_index   => 2
})

GameData::ContestType.register({
  :id           => :SMART,
  :name         => _INTL("Smart"),
  :long_name    => _INTL("Smartness"),
  :icon_index   => 3
})

GameData::ContestType.register({
  :id           => :TOUGH,
  :name         => _INTL("Tough"),
  :long_name    => _INTL("Toughness"),
  :icon_index   => 4
})