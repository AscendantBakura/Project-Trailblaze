module PMDDungeon
  def self.dungeon_map_active?
    return false if !$game_map
    return true if $game_map.metadata&.has_flag?("dungeonDisplay")
    return Config::MAIN_DUNGEON_MAP_IDS.include?($game_map.map_id)
  end

  def self.encounter_rule_matches_floor?(rule_floors, floor)
    case rule_floors
    when nil
      true
    when Integer
      rule_floors == floor
    when Range
      rule_floors.cover?(floor)
    when Array
      rule_floors.include?(floor)
    else
      false
    end
  end

  def self.pick_dungeon_wild_species(floor)
    pool = EventConfig::EVENT_POOL.select do |rule|
      encounter_rule_matches_floor?(rule[:floors], floor)
    end
    return nil if pool.empty?

    total_weight = pool.sum { |rule| rule[:weight] || 1 }
    pick = rand * total_weight
    running = 0
    pool.each do |rule|
      running += (rule[:weight] || 1)
      return rule[:species] if pick < running
    end
    return pool.sample[:species]
  end

  def self.dungeon_wild_level_for_floor(floor, fallback_level)
    base_level = [4 + (floor * 2), fallback_level.to_i].max
    return [[base_level, 1].max, 100].min
  end
end

EventHandlers.add(:on_wild_species_chosen, :pmdmaze_override_dungeon_wild_species,
  proc { |encounter|
    next if !encounter || encounter.length < 2
    next unless PMDDungeon.dungeon_map_active?

    floor = PMDDungeon.current_floor
    species = PMDDungeon.pick_dungeon_wild_species(floor)
    next if species.nil?

    encounter[0] = species
    encounter[1] = PMDDungeon.dungeon_wild_level_for_floor(floor, encounter[1])
  }
)
