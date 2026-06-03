module PMDDungeon
  def self.current_floor
    $PokemonGlobal.dungeonFloor || 0
  end

  def self.current_dungeon_map_id
    return $game_map.map_id if $game_map && $game_map.respond_to?(:map_id)
    return map_id_for_floor(current_floor)
  end

  def self.max_events_for_floor(floor, dungeon_map_id = nil)
    dungeon_map_id ||= current_dungeon_map_id
    dungeon_config = EventConfig::MAX_EVENTS_BY_DUNGEON_AND_FLOOR[dungeon_map_id] || {}
    
    dungeon_config.each do |floor_spec, max_count|
      case floor_spec
      when Integer
        return max_count if floor_spec == floor
      when Range
        return max_count if floor_spec.cover?(floor)
      when Array
        return max_count if floor_spec.include?(floor)
      end
    end
    
    EventConfig::MAX_EVENTS_PER_FLOOR
  end

  def self.sync_floor_variable
    return if Config::DUNGEON_FLOOR_VARIABLE_ID.nil?
    return if !$game_variables
    $game_variables[Config::DUNGEON_FLOOR_VARIABLE_ID] = current_floor
  end

  def self.reset_run_state!
    $PokemonGlobal.dungeonFloor = 0
    $PokemonGlobal.dungeonStepCounter = 0
    $PokemonGlobal.dungeonSpawnedItems = Hash.new(0)
    $PokemonGlobal.dungeonSpawnedSpecies = Hash.new(0)
    $PokemonGlobal.dungeonSpawnedNpcs = Hash.new(0)
    $PokemonGlobal.dungeonNpcQuestState = {}
    $PokemonGlobal.dungeonSpawnedTraps = Hash.new(0)
    $PokemonGlobal.dungeonLastTrapFloor = {}
    $PokemonGlobal.dungeonLastItemFloor = {}
    $PokemonGlobal.dungeonLastSpeciesFloor = {}
    $PokemonGlobal.dungeonEncounters = {}
    $PokemonGlobal.saveDungeonLayout = nil
    $PokemonGlobal.dungeonVisitedTiles = {}
    $PokemonGlobal.dungeonRevealedTraps = {}
  end

  def self.initialize_dungeon_run
    reset_run_state!
  end

  def self.prepare_floor(floor)
    $PokemonGlobal.dungeon_area = :tower
    $PokemonGlobal.dungeonFloor = floor
    $PokemonGlobal.dungeonStepCounter = 0
    sync_floor_variable
    $PokemonGlobal.dungeonEncounters = {}
    $PokemonGlobal.dungeonVisitedTiles = {}
    $PokemonGlobal.saveDungeonLayout = nil
    $PokemonGlobal.sawStairs = false
    $PokemonGlobal.dungeonRevealedTraps = {}
    PMDDungeon.reset_floor_event_state(floor)
  end

  def self.map_id_for_floor(floor = current_floor)
    Config::DUNGEON_MAP_BY_FLOOR.each do |range, map_id|
      return map_id if range.cover?(floor)
    end
    return Config::MAIN_DUNGEON_MAP_IDS.first
  end

  def self.transfer_to_floor_map(show_floor_card = false)
    pbFadeOutIn do
      NextFloor.new if show_floor_card

      map_id = map_id_for_floor
      $game_temp.player_new_map_id    = map_id
      $game_temp.player_new_direction = 2
      pbDismountBike
      if $game_temp.respond_to?(:dungeon_layout_sprite)
        $game_temp.dungeon_layout_sprite&.dispose
        $game_temp.dungeon_layout_sprite = nil
        $game_temp.dungeon_player&.dispose
        $game_temp.dungeon_player = nil
        $game_temp.dungeon_events&.dispose
        $game_temp.dungeon_events = nil
        $game_temp.dungeon_trap_last_tile = {}
      end
      $game_map.setup(map_id) if $game_map.map_id == map_id
      $scene.transfer_player
      $game_map.autoplay
      $game_map.refresh
    end
  end

  def self.start_dungeon_exploration(start_floor = 1)
    initialize_dungeon_run
    prepare_floor(start_floor)
    transfer_to_floor_map(true)
  end

  def self.advance_to_next_floor
    next_floor = current_floor + 1
    milestone = milestone_for_floor(next_floor)
    if milestone
      prepare_floor(next_floor)
      handled = handle_milestone(milestone)
      return if handled
    else
      prepare_floor(next_floor)
    end
    transfer_to_floor_map(true)
  end

  def self.travel_to_floor(target_floor)
    prepare_floor(target_floor)
    transfer_to_floor_map(true)
  end

  def self.reveal_around_player(radius = 3)
    return false unless $PokemonGlobal && $game_player
    px = $game_player.x
    py = $game_player.y
    visited = $PokemonGlobal.dungeonVisitedTiles
    new_tiles = false
    (-radius..radius).each do |dx|
      (-radius..radius).each do |dy|
        key = "#{px + dx},#{py + dy}"
        unless visited[key]
          visited[key] = true
          new_tiles = true
        end
      end
    end
    return new_tiles
  end
end

class PokemonGlobalMetadata
  attr_accessor :dungeonFloor
  attr_accessor :dungeonEncounters
  attr_accessor :dungeonStepCounter
  attr_accessor :dungeonSpawnedItems
  attr_accessor :dungeonSpawnedSpecies
  attr_accessor :dungeonLastItemFloor
  attr_accessor :dungeonLastSpeciesFloor
  attr_accessor :dungeonNpcQuestState

  def dungeonFloor
    @dungeonFloor ||= 0
    return @dungeonFloor
  end

  def dungeonEncounters
    @dungeonEncounters ||= {}
    return @dungeonEncounters
  end

  def dungeonSpawnedItems
    @dungeonSpawnedItems ||= Hash.new(0)
    return @dungeonSpawnedItems
  end

  def dungeonSpawnedSpecies
    @dungeonSpawnedSpecies ||= Hash.new(0)
    return @dungeonSpawnedSpecies
  end

  def dungeonLastItemFloor
    @dungeonLastItemFloor ||= {}
    return @dungeonLastItemFloor
  end

  def dungeonLastSpeciesFloor
    @dungeonLastSpeciesFloor ||= {}
    return @dungeonLastSpeciesFloor
  end

  def dungeonNpcQuestState
    @dungeonNpcQuestState ||= {}
    return @dungeonNpcQuestState
  end

  attr_accessor :dungeonVisitedTiles
  attr_accessor :dungeonSpawnedNpcs

  def dungeonVisitedTiles
    @dungeonVisitedTiles ||= {}
    return @dungeonVisitedTiles
  end

  def dungeonSpawnedNpcs
    @dungeonSpawnedNpcs ||= Hash.new(0)
    return @dungeonSpawnedNpcs
  end

  attr_accessor :dungeonSpawnedTraps
  attr_accessor :dungeonLastTrapFloor

  def dungeonSpawnedTraps
    @dungeonSpawnedTraps ||= Hash.new(0)
    return @dungeonSpawnedTraps
  end

  def dungeonLastTrapFloor
    @dungeonLastTrapFloor ||= {}
    return @dungeonLastTrapFloor
  end

  attr_accessor :dungeonRevealedTraps

  def dungeonRevealedTraps
    @dungeonRevealedTraps ||= {}
    return @dungeonRevealedTraps
  end
end

def pbStartDungeon(start_floor = 1)
  PMDDungeon.start_dungeon_exploration(start_floor)
end

def pbGoToDungeonFloor(target_floor)
  PMDDungeon.travel_to_floor(target_floor)
end

def pbDungeonNextFloor
  PMDDungeon.advance_to_next_floor
end
