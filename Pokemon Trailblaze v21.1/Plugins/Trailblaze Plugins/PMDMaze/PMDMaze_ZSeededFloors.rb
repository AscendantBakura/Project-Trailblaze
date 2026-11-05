#===============================================================================
# PMDMaze - Seeded, persistent dungeon floors (Trailblaze restoration)
#   * pbStartDungeon(start_floor = 1, seed = nil, map: nil)
#   * Every floor of a run is generated from a per-floor seed derived from the
#     run seed, then snapshotted (tiles, events, layout) so that revisits and
#     save reloads show the exact same floor, minus consumed events.
#   * Up stairs ("stairs_up") return to the previous floor; on floor 1 they
#     offer to leave the dungeon and return to the entrance.
#   * Arrival is placed beside the matching stairs; milestones only fire on
#     the first visit of a floor.
#   * PMDDungeon::Layout.secure_floor! runs on every new floor: all rooms,
#     both stairs and interactive events reachable, stairs neighbours clear.
#===============================================================================
module PMDDungeon
  module SeededFloors
    LADDER_TILES_BY_TILESET = {
      44 => { bottom: 384 + 46, top: 384 + 38 }   # Beginner Park ladder (2 tiles)
    }
    DEFAULT_UP_TILE = 384 + 47

    module_function

    def floor_seed(run_seed, floor, map_id)
      return ((run_seed.to_i * 1_000_003) + (floor.to_i * 7_919) + (map_id.to_i * 104_729)) % 2_147_483_647
    end

    def run
      $PokemonGlobal.pmdSeededRun ||= {}
      return $PokemonGlobal.pmdSeededRun
    end

    def run_active?
      return false if !$PokemonGlobal
      return run[:active] ? true : false
    end

    def snapshots
      run[:floors] ||= {}
      return run[:floors]
    end

    def floor_state(floor)
      run[:state] ||= {}
      run[:state][floor] ||= { visited: {}, revealed: {}, saw_stairs: false, consumed: [] }
      return run[:state][floor]
    end

    def visited_floor?(floor)
      return snapshots.has_key?(floor)
    end

    def begin_run(seed, map_override, start_floor)
      entrance = nil
      if $game_map && $game_player
        entrance = [$game_map.map_id, $game_player.x, $game_player.y, $game_player.direction]
      end
      id = DataStore.dungeon_id(map_override || 108)
      data = DataStore.bundle && DataStore.bundle['pmd_dungeons'][id]
      entrance = data['EntryDestination'] if data && data['EntryMode'] == :fixed
      $PokemonGlobal.pmdSeededRun = {
        active:   true,
        seed:     (seed || rand(2_147_483_646) + 1).to_i,
        map:      map_override,
        entrance: entrance,
        previous_bgm: (defined?($game_system) && $game_system && $game_system.respond_to?(:getPlayingBGM) ? $game_system.getPlayingBGM : nil),
        start:    start_floor,
        dungeon_id: id,
        floors:   {},
        state:    {},
        arrival:  :start
      }
    end

    def end_run
      return if !$PokemonGlobal
      $PokemonGlobal.pmdSeededRun = {}
      PMDDungeon::Allies.sync_partner if PMDDungeon.const_defined?(:Allies)
    end

    #---------------------------------------------------------------------------
    # Pure helpers (also used by synthetic tests)
    #---------------------------------------------------------------------------
    def layout_lines(layout)
      return [] if !layout
      lines = layout.lines.map(&:chomp)
      width = lines.map(&:size).max || 0
      return lines.map { |l| l.ljust(width, "#") }
    end

    # Breadth-first flood over walkable tiles. walkable is a proc(x, y).
    def reachable_from(start_x, start_y, width, height, walkable)
      seen = {}
      return seen if !walkable.call(start_x, start_y)
      queue = [[start_x, start_y]]
      seen[[start_x, start_y]] = true
      until queue.empty?
        x, y = queue.shift
        [[1, 0], [-1, 0], [0, 1], [0, -1]].each do |dx, dy|
          nx = x + dx
          ny = y + dy
          next if nx < 0 || ny < 0 || nx >= width || ny >= height
          next if seen[[nx, ny]]
          next if !walkable.call(nx, ny)
          seen[[nx, ny]] = true
          queue << [nx, ny]
        end
      end
      return seen
    end

    def adjacent_free_tile(x, y, walkable, occupied)
      [[0, 1], [1, 0], [-1, 0], [0, -1], [1, 1], [-1, 1], [1, -1], [-1, -1]].each do |dx, dy|
        nx = x + dx
        ny = y + dy
        next if !walkable.call(nx, ny)
        next if occupied[[nx, ny]]
        return [nx, ny]
      end
      return nil
    end

    #---------------------------------------------------------------------------
    # Map helpers working on RPG::Map during :on_game_map_setup
    #---------------------------------------------------------------------------
    def tile_passable?(map, x, y)
      return false if x < 0 || y < 0 || x >= map.width || y >= map.height
      tileset = $data_tilesets[map.tileset_id]
      return true if !tileset
      passages = tileset.passages
      priorities = tileset.priorities
      [2, 1, 0].each do |z|
        tile = map.data[x, y, z]
        next if tile.nil? || tile == 0
        return false if (passages[tile] & 0x0f) == 0x0f
        return true if priorities[tile] == 0
      end
      return true
    end

    def walkable_proc(map, layout = nil)
      lines = layout_lines(layout)
      return proc { |x, y|
        next false if x < 0 || y < 0 || x >= map.width || y >= map.height
        if !lines.empty?
          row = lines[y]
          next false if !row || row[x].nil? || row[x] == "#"
        end
        tile_passable?(map, x, y)
      }
    end

    def occupied_tiles(map, except_id = nil)
      occ = {}
      map.events.each_value do |ev|
        next if ev.id == except_id
        occ[[ev.x, ev.y]] = true
      end
      return occ
    end

    def find_event(map, regexp)
      map.events.each_value { |ev| return ev if ev.name.to_s[regexp] }
      return nil
    end

    def stairs_down_event(map)
      map.events.each_value do |ev|
        name = ev.name.to_s
        next if name[/stairs_up|ladder_top/i]
        return ev if name[/stairs/i]
      end
      return nil
    end

    def build_event(id, x, y, name, script, trigger: 0, character_name: "", tile_id: 0,
                    through: false, priority: 1, move_type: 0, speed: 3, freq: 3, direction: 2,
                    always_on_top: false, step_anime: false)
      ev = RPG::Event.new(x, y)
      ev.id = id
      ev.name = name
      page = ev.pages[0]
      page.trigger = trigger
      page.graphic.tile_id = tile_id
      page.graphic.character_name = character_name.to_s
      page.graphic.direction = direction
      page.through = through
      page.always_on_top = always_on_top
      page.step_anime = step_anime
      page.move_type = move_type
      page.move_speed = speed
      page.move_frequency = freq
      page.direction_fix = (tile_id > 0)
      page.instance_variable_set(:@priority_type, priority) if page.instance_variable_defined?(:@priority_type)
      page.list = []
      if script && !script.empty?
        lines = script.split("\n")
        page.list << RPG::EventCommand.new(355, 0, [lines.shift])
        lines.each { |l| page.list << RPG::EventCommand.new(655, 0, [l]) }
      end
      page.list << RPG::EventCommand.new(0, 0, [])
      return ev
    end

    def next_event_id(map)
      return (map.events.keys.max || 0) + 1
    end

    # Adds "stairs_up" (+ decorative "ladder_top") at the arrival tile.
    def add_up_stairs(map, x, y)
      palette = DataStore.palette
      tiles = palette ? { bottom: palette.fetch('StairsUp', 431), top: palette.fetch('LadderTop', 0) } : LADDER_TILES_BY_TILESET[map.tileset_id]
      tiles[:top] = nil if tiles && tiles[:top] == 0
      bottom = tiles ? tiles[:bottom] : DEFAULT_UP_TILE
      id = next_event_id(map)
      map.events[id] = build_event(id, x, y, "stairs_up", "pbDungeonPreviousFloor",
                                   trigger: 1, tile_id: bottom, priority: 0)
      blocked = [[x, y]]
      if tiles && tiles[:top] && y > 0
        top_id = next_event_id(map)
        map.events[top_id] = build_event(top_id, x, y - 1, "ladder_top", nil,
                                         trigger: 0, tile_id: tiles[:top], through: true,
                                         always_on_top: true)
        blocked << [x, y - 1]
      end
      # Park anything generated under the ladder off-map; ensure_reachability
      # moves it onto a free reachable tile.
      map.events.each_value do |ev|
        next if ev.name.to_s[/\A(stairs_up|ladder_top)\z|time of day/i]
        next if !blocked.include?([ev.x, ev.y])
        ev.instance_variable_set(:@pmd_displaced, [ev.x, ev.y])
        ev.x = ev.y = -1
      end
      return map.events[id]
    end

    # Moves every event that can't be reached from (sx, sy) onto reachable tiles.
    def ensure_reachability(map, sx, sy, layout)
      walk = walkable_proc(map, layout)
      reach = reachable_from(sx, sy, map.width, map.height, walk)
      return 0 if reach.empty?
      free = reach.keys.shuffle
      occ = occupied_tiles(map)
      occ[[sx, sy]] = true
      moved = 0
      map.events.values.sort_by(&:id).each do |ev|
        next if ev.name.to_s[/ladder_top|time of day/i]
        next if reach[[ev.x, ev.y]]
        # events standing on walls but touching a reachable tile are fine (counters)
        next if [[1, 0], [-1, 0], [0, 1], [0, -1]].any? { |dx, dy| reach[[ev.x + dx, ev.y + dy]] } && !ev.name.to_s[/stairs|_item_|_trap_/i]
        dest = free.find { |t| !occ[t] }
        dest ||= ev.instance_variable_get(:@pmd_displaced)
        next if !dest
        occ.delete([ev.x, ev.y])
        ev.x, ev.y = dest
        occ[dest] = true
        moved += 1
      end
      map.events.each_value do |ev|
        ev.remove_instance_variable(:@pmd_displaced) if ev.instance_variable_defined?(:@pmd_displaced)
      end
      return moved
    end

    def snapshot!(floor, map_id, map, extra = {})
      snapshots[floor] = {
        map_id: map_id,
        width:  map.width,
        height: map.height,
        data:   Marshal.dump(map.data),
        events: Marshal.dump(map.events),
        layout: $PokemonGlobal.saveDungeonLayout
      }.merge(extra)
    end

    def restore!(floor, map)
      snap = snapshots[floor]
      map.width  = snap[:width]
      map.height = snap[:height]
      map.data   = Marshal.load(snap[:data])
      events = Marshal.load(snap[:events])
      floor_state(floor)[:consumed].each { |id| events.delete(id) }
      map.events = events
      $PokemonGlobal.saveDungeonLayout = snap[:layout]
    end

    def place_arrival(map, floor, layout)
      arrival = run[:arrival]
      run[:arrival] = nil
      return if arrival.nil?
      walk = walkable_proc(map, layout)
      occ = occupied_tiles(map)
      target = case arrival
               when :up   then stairs_down_event(map)
               else            find_event(map, /\Astairs_up\z/i)
               end
      return if !target
      spot = adjacent_free_tile(target.x, target.y, walk, occ)
      spot ||= [target.x, target.y + 1]
      $game_temp.player_new_x = spot[0]
      $game_temp.player_new_y = spot[1]
      $game_temp.player_new_direction = 2
    end

    def on_map_setup(original, map_id, map, tileset)
      old_context = DataStore.context_map
      DataStore.context_map = map_id
      dungeon_data = DataStore.current
      palette = dungeon_data && dungeon_data['MapIDs'].include?(map_id) ? DataStore.palette : nil
      map.tileset_id = palette['Tileset'] if palette
      metadata = GameData::MapMetadata.try_get(map_id)
      is_dungeon = metadata&.random_dungeon || PMDDungeon::DataStore.setting(:Config, :MAIN_DUNGEON_MAP_IDS).include?(map_id)
      floor = $PokemonGlobal ? $PokemonGlobal.dungeonFloor.to_i : 0
      if !is_dungeon || !run_active? || floor <= 0
        original&.call(map_id, map, tileset)
        return
      end
      snap = snapshots[floor]
      if snap && snap[:map_id] == map_id
        restore!(floor, map)
      else
        seed = floor_seed(run[:seed], floor, map_id)
        Random.srand(seed)
        $PokemonGlobal.dungeon_rng_seed = seed
        layout_mod = PMDDungeon.const_defined?(:Layout) ? PMDDungeon::Layout : nil
        layout_mod&.reset_capture
        original&.call(map_id, map, tileset)
        layout = $PokemonGlobal.saveDungeonLayout
        sx = $game_temp.player_new_x
        sy = $game_temp.player_new_y
        down = stairs_down_event(map)
        down.pages[0].graphic.tile_id = palette.fetch('StairsDown', 431) if down && palette
        add_up_stairs(map, sx, sy) if sx && sy
        PMDDungeon::Features.populate_floor(map, floor, layout, sx, sy) if PMDDungeon.const_defined?(:Features) && PMDDungeon::Features.respond_to?(:populate_floor)
        ensure_reachability(map, sx, sy, layout) if sx && sy
        extra = {}
        if layout_mod && sx && sy
          report = layout_mod.secure_floor!(map, layout, sx, sy)
          extra = { rooms: report[:rooms], reserved: layout_mod.floor_reserved || [], report: report,
                    tileset_id: map.tileset_id, decor: layout_mod.last_decor || {} }
        end
        snapshot!(floor, map_id, map, extra)
        Random.srand(Random.new_seed % 2_147_483_647)
        run[:arrival] = :down if run[:arrival].nil? || run[:arrival] == :start
      end
      place_arrival(map, floor, $PokemonGlobal.saveDungeonLayout)
    ensure
      DataStore.context_map = old_context
    end

    def install!
      events = EventHandlers.class_variable_get(:@@events) rescue nil
      named = events && events[:on_game_map_setup]
      callbacks = named && named.instance_variable_get(:@callbacks)
      original = callbacks && callbacks[:random_dungeon]
      return if original.nil? || original.instance_variable_get(:@pmd_seeded_wrapper)
      EventHandlers.remove(:on_game_map_setup, :random_dungeon)
      wrapper = proc { |map_id, map, tileset| PMDDungeon::SeededFloors.on_map_setup(original, map_id, map, tileset) }
      wrapper.instance_variable_set(:@pmd_seeded_wrapper, true)
      EventHandlers.add(:on_game_map_setup, :random_dungeon, wrapper)
    end
  end

  class << self
    alias pmd_seeded_map_id_for_floor map_id_for_floor unless method_defined?(:pmd_seeded_map_id_for_floor)
    def map_id_for_floor(floor = current_floor)
      data = DataStore.current
      if data && SeededFloors.run_active?
        route = DataStore.rows(data, 'FloorMap').find { |r| DataStore.covers?(r[0], floor) }
        return route ? route[1] : data['MapIDs'].first
      end
      if $PokemonGlobal && SeededFloors.run_active? && SeededFloors.run[:map]
        return SeededFloors.run[:map]
      end
      return pmd_seeded_map_id_for_floor(floor)
    end

    alias pmd_seeded_prepare_floor prepare_floor unless method_defined?(:pmd_seeded_prepare_floor)
    def prepare_floor(floor)
      if SeededFloors.run_active? && current_floor > 0
        st = SeededFloors.floor_state(current_floor)
        st[:visited]    = $PokemonGlobal.dungeonVisitedTiles
        st[:revealed]   = $PokemonGlobal.dungeonRevealedTraps
        st[:saw_stairs] = $PokemonGlobal.sawStairs
      end
      pmd_seeded_prepare_floor(floor)
      return if !SeededFloors.run_active? || !SeededFloors.visited_floor?(floor)
      st = SeededFloors.floor_state(floor)
      $PokemonGlobal.dungeonVisitedTiles  = st[:visited] || {}
      $PokemonGlobal.dungeonRevealedTraps = st[:revealed] || {}
      $PokemonGlobal.sawStairs            = st[:saw_stairs] || false
      $PokemonGlobal.saveDungeonLayout    = SeededFloors.snapshots[floor][:layout]
    end

    alias pmd_seeded_advance_to_next_floor advance_to_next_floor unless method_defined?(:pmd_seeded_advance_to_next_floor)
    def advance_to_next_floor
      return pmd_seeded_advance_to_next_floor if !SeededFloors.run_active?
      next_floor = current_floor + 1
      limit = DataStore.current && DataStore.current['FloorLimit'].to_i
      return exit_dungeon_run if limit && limit > 0 && next_floor > limit
      SeededFloors.run[:arrival] = :down
      if SeededFloors.visited_floor?(next_floor)
        prepare_floor(next_floor)
        transfer_to_floor_map(true)
        return
      end
      pmd_seeded_advance_to_next_floor
      # milestones such as :teleport_away / :end_of_area reset the run
      SeededFloors.end_run if current_floor <= 0
    end

    alias pmd_seeded_travel_to_floor travel_to_floor unless method_defined?(:pmd_seeded_travel_to_floor)
    def travel_to_floor(target_floor)
      if SeededFloors.run_active?
        SeededFloors.run[:arrival] = (target_floor < current_floor) ? :up : :down
      end
      pmd_seeded_travel_to_floor(target_floor)
    end

    def return_to_previous_floor
      prev = current_floor - 1
      return leave_dungeon_from_first_floor if prev < 1
      SeededFloors.run[:arrival] = :up
      prepare_floor(prev)
      transfer_to_floor_map(true)
    end

    def leave_dungeon_from_first_floor
      return false if !pbConfirmMessage(_INTL("Leave the dungeon?"))
      exit_dungeon_run
      return true
    end

    # Ends the current run and returns the player to the entrance (or to an
    # explicit destination [map_id, x, y, direction]).
    def exit_dungeon_run(destination = nil)
      config = DataStore.current
      fixed_exit = config && config['ExitMode'] == :fixed && config['ExitDestination']
      dest = destination || fixed_exit || SeededFloors.run[:entrance]
      PMDDungeon::Features.on_run_end if PMDDungeon.const_defined?(:Features) && PMDDungeon::Features.respond_to?(:on_run_end)
      SeededFloors.end_run
      reset_run_state!
      sync_floor_variable
      return if !dest
      pbFadeOutIn do
        $game_temp.player_new_map_id    = dest[0]
        $game_temp.player_new_x         = dest[1]
        $game_temp.player_new_y         = dest[2]
        $game_temp.player_new_direction = dest[3] || 2
        pbDismountBike
        $scene.transfer_player if $scene.is_a?(Scene_Map)
        $game_map.autoplay
        $game_map.refresh
      end
    end
  end
end

class PokemonGlobalMetadata
  attr_writer :pmdSeededRun

  def pmdSeededRun
    @pmdSeededRun ||= {}
    return @pmdSeededRun
  end
end

class Game_Event
  alias pmd_seeded_erase erase unless method_defined?(:pmd_seeded_erase)

  def erase
    if !@pmd_live && $PokemonGlobal && PMDDungeon::SeededFloors.run_active? && @map_id == $game_map&.map_id &&
       PMDDungeon.respond_to?(:dungeon_map_active?) && PMDDungeon.dungeon_map_active?
      consumed = PMDDungeon::SeededFloors.floor_state(PMDDungeon.current_floor)[:consumed]
      consumed << @id if !consumed.include?(@id)
    end
    pmd_seeded_erase
  end
end

PMDDungeon::SeededFloors.install!

def pbStartDungeon(start_floor = nil, seed = nil, map: nil, dungeon: nil)
  if PMDDungeon::DataStore.bundle
    id = dungeon || PMDDungeon::DataStore.dungeon_id(map || 108)
    data = PMDDungeon::DataStore.bundle['pmd_dungeons'][id]
    raise PMDDungeon::DataStore::Error, "Unknown dungeon #{id || map}" unless data
    map ||= data['MapIDs'].first
    start_floor ||= data.fetch('StartFloor', 1)
    raise ArgumentError, 'Start floor outside dungeon limits' if start_floor < 1 || data['FloorLimit'].to_i > 0 && start_floor > data['FloorLimit']
  end
  start_floor ||= 1
  PMDDungeon::SeededFloors.begin_run(seed, map, start_floor)
  PMDDungeon::Features.on_run_start(start_floor) if PMDDungeon.const_defined?(:Features) && PMDDungeon::Features.respond_to?(:on_run_start)
  PMDDungeon.start_dungeon_exploration(start_floor)
end

def pbDungeonPreviousFloor
  PMDDungeon.return_to_previous_floor
end

def pbLeaveDungeon
  PMDDungeon.exit_dungeon_run
end
