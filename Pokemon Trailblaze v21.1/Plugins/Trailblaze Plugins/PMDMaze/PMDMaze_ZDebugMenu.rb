#===============================================================================
# PMDMaze - Dungeon debug tools (Trailblaze restoration), $DEBUG only.
#   * Native debug menu (F9) entry "PMD dungeon tools..." under the main list.
#   * pbDungeonDebugMenu            -> interactive command list
#     pbDungeonDebugMenu(:cmd, ...) -> runs one command directly (driver/tests)
#   Commands that move the player are deferred until the debug menu closes.
#   No free-form script evaluation is offered.
#===============================================================================
module PMDDungeon
  module DebugMenu
    COMMANDS = [
      [:info,            "Run info"],
      [:start_run,       "Start run (seed/floor)"],
      [:goto_floor,      "Go to floor"],
      [:floor_up,        "Floor up (previous)"],
      [:floor_down,      "Floor down (next)"],
      [:end_run,         "End run / leave"],
      [:validate,        "Connectivity report"],
      [:add_pokemon,     "Add party Pokémon"],
      [:heal,            "Heal party + ally"],
      [:recruit_ally,    "Recruit ally here"],
      [:dismiss_ally,    "Dismiss ally"],
      [:force_win,       "Force next battle: win"],
      [:force_loss,      "Force next battle: loss"],
      [:force_clear,     "Clear forced battle result"],
      [:foe_here,        "F.O.E. onto this floor"],
      [:foe_floor,       "Set F.O.E. floor"],
      [:foe_climb,       "F.O.E. climb step"],
      [:hunter_now,      "Spawn hunter now"],
      [:steps,           "Take step triggers"],
      [:spawn_criminal,  "Spawn fleeing criminal"],
      [:accept_bounty,   "Accept bounty"],
      [:smuggler,        "Open smuggler (floor stock)"],
      [:restock,         "Restock smuggler"],
      [:assets,          "Asset report"]
    ]
    DEFERRED = [:start_run, :goto_floor, :floor_up, :floor_down, :end_run]

    class << self
      attr_accessor :forced_outcome, :in_native_menu
    end

    module_function

    def features
      return PMDDungeon::Features
    end

    def queue
      @queue ||= []
      return @queue
    end

    def allowed?
      return $DEBUG ? true : false
    end

    def menu
      return nil if !allowed?
      loop do
        labels = COMMANDS.map { |_, l| _INTL(l) } + [_INTL("Close")]
        idx = pbShowCommands(nil, labels, -1)
        break if idx < 0 || idx >= COMMANDS.length
        cmd = COMMANDS[idx][0]
        args = prompt_args(cmd)
        next if args.nil?
        ret = begin
                run(cmd, **args)
              rescue ArgumentError => e
                e.message
              end
        break if DEFERRED.include?(cmd) && !in_native_menu
        pbMessage(format_result(ret)) if ret.is_a?(String) || ret.is_a?(Array)
      end
      return nil
    end

    def number(text, min, max, default)
      params = ChooseNumberParams.new
      params.setRange(min, max)
      params.setDefaultValue(default.clamp(min, max))
      params.setCancelValue(-1)
      return pbMessageChooseNumber(text, params)
    end

    def prompt_args(cmd)
      case cmd
      when :start_run
        dungeon = nil
        if DataStore.bundle
          ids = DataStore.bundle['pmd_dungeons'].keys
          names = ids.map { |id| DataStore.bundle['pmd_dungeons'][id]['Name'] || id.to_s }
          choice = pbMessage(_INTL("Which dungeon?"), names, ids.length)
          return nil if choice < 0 || choice >= ids.length
          dungeon = ids[choice]
        end
        seed = number(_INTL("Seed (0 = random)?"), 0, 999_999_999, 1234)
        return nil if seed < 0
        fl = number(_INTL("Start floor?"), 1, 99, 1)
        return nil if fl < 0
        return { seed: seed == 0 ? nil : seed, floor: fl, dungeon: dungeon }
      when :goto_floor
        fl = number(_INTL("Floor?"), 1, 99, [PMDDungeon.current_floor, 1].max)
        return fl < 0 ? nil : { floor: fl }
      when :foe_floor
        fl = number(_INTL("F.O.E. floor?"), 1, 99, [PMDDungeon.current_floor, 1].max)
        return fl < 0 ? nil : { floor: fl }
      when :steps
        n = number(_INTL("How many steps?"), 1, 999, 10)
        return n < 0 ? nil : { count: n }
      when :add_pokemon
        species = pbChooseSpeciesList rescue nil
        return nil if !species
        lvl = number(_INTL("Level?"), 1, GameData::GrowthRate.max_level, 10)
        return lvl < 0 ? nil : { species: species, level: lvl }
      when :recruit_ally
        ids = PMDDungeon::DataStore.setting(:FeatureConfig, :ALLIES).keys
        i = pbShowCommands(nil, ids.map(&:to_s), -1)
        return i < 0 ? nil : { id: ids[i] }
      when :spawn_criminal
        list = PMDDungeon::DataStore.setting(:FeatureConfig, :CRIMINALS)
        i = pbShowCommands(nil, list.map { |c| c[:name] }, -1)
        return i < 0 ? nil : { index: i }
      when :accept_bounty
        list = PMDDungeon::DataStore.setting(:FeatureConfig, :BOUNTIES)
        i = pbShowCommands(nil, list.map { |b| b[:name] }, -1)
        return i < 0 ? nil : { id: list[i][:id] }
      end
      return {}
    end

    def format_result(ret)
      return ret.join("\n") if ret.is_a?(Array)
      return ret.to_s
    end

    # Runs one command. Movement commands are queued while the native debug
    # menu is open (it cannot be closed from a handler) and run on close.
    def run(cmd, **args)
      raise ArgumentError, "Debug mode is off" if !allowed?
      raise ArgumentError, "Unknown dungeon debug command #{cmd}" if !COMMANDS.any? { |c, _| c == cmd }
      if DEFERRED.include?(cmd) && in_native_menu
        queue << [cmd, args]
        return _INTL("Queued; runs when the debug menu closes.")
      end
      return send(:"cmd_#{cmd}", **args)
    end

    def flush_queue
      return if queue.empty? || in_native_menu
      return if !$scene.is_a?(Scene_Map) || pbMapInterpreterRunning? || $game_temp.in_menu
      cmd, args = queue.shift
      send(:"cmd_#{cmd}", **args)
    end

    #---------------------------------------------------------------------------
    def info_lines
      sf = PMDDungeon::SeededFloors
      lines = []
      if sf.run_active?
        rd = features.run_data
        lines << "Run seed #{sf.run[:seed]} floor #{PMDDungeon.current_floor} map #{$game_map&.map_id}"
        lines << "Floors stored: #{sf.snapshots.keys.sort.join(',')}"
        lines << "FOE floor #{rd[:foe_floor].inspect} steps #{rd[:foe_steps]} entry #{rd[:foe_entry].inspect} species #{rd[:foe_species].inspect} defeated #{!!rd[:foe_defeated]}"
        lines << format("Time on floor %.0fs / %ss hunter %s species %s", features.floor_seconds,
                        PMDDungeon::DataStore.setting(:FeatureConfig, :HUNTER_SECONDS),
                        (rd[:hunter] || {}).inspect, (rd[:hunter_species] || {}).inspect)
        lines << "Criminals #{(rd[:criminals] || {}).inspect}"
      else
        lines << "No dungeon run active (map #{$game_map&.map_id})"
      end
      cfg = PMDDungeon::FeatureConfig
      lines << "Law #{$game_variables[PMDDungeon::DataStore.setting(:FeatureConfig, :LAW_VARIABLE)]} Chaos #{$game_variables[PMDDungeon::DataStore.setting(:FeatureConfig, :CHAOS_VARIABLE)]}"
      lines << "Ally #{$PokemonGlobal.pmdAlly.inspect} partner #{PMDDungeon::Allies.partner_active?}"
      lines << "Forced battle result #{forced_outcome.inspect}"
      return lines
    end

    def cmd_info
      return info_lines
    end

    def cmd_start_run(seed: nil, floor: nil, dungeon: nil, map: nil)
      pbLeaveDungeon if PMDDungeon::SeededFloors.run_active?
      pbStartDungeon(floor, seed, dungeon: dungeon, map: map)
      return info_lines
    end

    def require_run
      raise ArgumentError, "No dungeon run active" if !PMDDungeon::SeededFloors.run_active?
    end

    def cmd_goto_floor(floor:)
      require_run
      PMDDungeon.travel_to_floor(floor)
      return info_lines
    end

    def cmd_floor_up
      require_run
      pbDungeonPreviousFloor
      return info_lines
    end

    def cmd_floor_down
      require_run
      PMDDungeon.advance_to_next_floor
      return info_lines
    end

    def cmd_end_run
      pbLeaveDungeon if PMDDungeon::SeededFloors.run_active?
      return info_lines
    end

    def cmd_validate(floor: nil)
      require_run
      floors = floor ? [floor] : PMDDungeon::SeededFloors.snapshots.keys.sort
      return floors.map do |f|
        r = PMDDungeon::Layout.validate_snapshot(f)
        next "F#{f}: no snapshot" if !r
        "F#{f}: #{r[:ok] ? 'OK' : 'PROBLEMS'} rooms #{r[:rooms]} up #{r[:stairs_up].inspect} " \
          "down #{r[:stairs_down].inspect} path #{r[:route].inspect} #{r[:problems].inspect}"
      end
    end

    def cmd_add_pokemon(species:, level: 10)
      pbAddPokemonSilent(species, level)
      return "Added #{species} Lv.#{level}"
    end

    def cmd_heal
      $player.heal_party
      PMDDungeon::Allies.heal
      return "Healed"
    end

    def cmd_recruit_ally(id: :HILDA)
      PMDDungeon::Allies.dismiss if PMDDungeon::Allies.active?
      PMDDungeon::Allies.join(id, nil)
      return info_lines
    end

    def cmd_dismiss_ally
      PMDDungeon::Allies.dismiss
      return info_lines
    end

    def cmd_force_win
      self.forced_outcome = :win
      return "Next battle: win"
    end

    def cmd_force_loss
      self.forced_outcome = :loss
      return "Next battle: loss"
    end

    def cmd_force_clear
      self.forced_outcome = nil
      return "Next battle: normal"
    end

    def cmd_foe_here
      require_run
      rd = features.run_data
      rd[:foe_floor] = PMDDungeon.current_floor
      rd[:foe_defeated] = false
      rd[:foe_entry] = :stairs_down
      features.ensure_chasers if !in_native_menu
      return info_lines
    end

    def cmd_foe_floor(floor:)
      require_run
      features.run_data[:foe_floor] = floor
      features.run_data[:foe_defeated] = false
      return info_lines
    end

    def cmd_foe_climb
      require_run
      rd = features.run_data
      rd[:foe_steps] = PMDDungeon::DataStore.setting(:FeatureConfig, :FOE_CLIMB_STEPS) - 1
      features.on_step
      return info_lines
    end

    def cmd_hunter_now
      require_run
      rd = features.run_data
      rd[:hunter] ||= {}
      rd[:hunter][PMDDungeon.current_floor] = :spawned
      features.ensure_chasers if !in_native_menu
      return info_lines
    end

    def cmd_steps(count: 1)
      count.times { features.on_step }
      return info_lines
    end

    def cmd_spawn_criminal(index: 0)
      require_run
      cfg = PMDDungeon::FeatureConfig
      info = PMDDungeon::DataStore.setting(:FeatureConfig, :CRIMINALS)[index] || PMDDungeon::DataStore.setting(:FeatureConfig, :CRIMINALS)[0]
      spot = [[0, 2], [2, 0], [-2, 0], [0, -2], [1, 1], [-1, 1]].map { |dx, dy| [$game_player.x + dx, $game_player.y + dy] }
                                                                .find { |x, y| $game_map.passable?(x, y, 2) && $game_map.events.values.none? { |e| e.x == x && e.y == y } }
      return "No free tile near the player" if !spot
      id = ($game_map.events.keys.max || 0) + 1
      rpg = PMDDungeon::SeededFloors.build_event(id, spot[0], spot[1], "_npc_CRIMINAL",
                                                 "PMDDungeon::Features.criminal(@event_id, #{index})",
                                                 trigger: 0, character_name: info[:graphic], move_type: 3,
                                                 speed: 4, freq: 5)
      rpg.pages[0].move_route = features.flee_route
      ev = Game_Event.new($game_map.map_id, rpg, $game_map)
      ev.instance_variable_set(:@pmd_live, true)
      $game_map.events[id] = ev
      spriteset = $scene.spriteset($game_map.map_id) rescue nil
      if spriteset && spriteset.respond_to?(:character_sprites)
        spriteset.character_sprites.push(Sprite_Character.new(Spriteset_Map.viewport, ev))
      end
      return "Criminal event #{id} at #{spot.inspect}"
    end

    def cmd_accept_bounty(id:)
      features.persistent[:bounties] ||= {}
      features.persistent[:bounties].each_key { |k| features.persistent[:bounties][k] = nil if features.persistent[:bounties][k] == :accepted }
      features.persistent[:bounties][id] = :accepted
      features.run_data[:bounty_placed] = false if PMDDungeon::SeededFloors.run_active?
      return "Bounty #{id} accepted; it appears on the next new floor in its range"
    end

    def cmd_smuggler
      fl = [PMDDungeon.current_floor, 1].max
      stock = PMDDungeon::SeededFloors.run_active? ? features.smuggler_stock(fl) : PMDDungeon::DataStore.setting(:FeatureConfig, :SMUGGLER_STOCK).to_h
      PMDDungeon::SmugglerShop.open(stock)
      return "Smuggler closed"
    end

    def cmd_restock
      require_run
      features.run_data[:smuggler]&.delete(PMDDungeon.current_floor)
      return features.smuggler_stock(PMDDungeon.current_floor).map { |i, q| "#{i} x#{q}" }
    end

    def cmd_assets
      lines = PMDDungeon::Allies.asset_report
      missing = PMDDungeon::SmugglerShop.missing_files
      lines << (missing.empty? ? "ok smuggler layers (#{PMDDungeon::SmugglerShop.layer_paths.length})" : "MISSING smuggler: #{missing.join(', ')}")
      PMDDungeon::DataStore.setting(:FeatureConfig, :TRAINERS).each do |t|
        lines << "#{pbResolveBitmap("Graphics/Trainers/#{t[:type]}") ? 'ok' : 'MISSING'} trainer #{t[:type]} / #{t[:graphic]}"
      end
      lines.concat(PMDDungeon::Portrait.missing.map { |m| "NOTE #{m}" })
      return lines
    end
  end
end

def pbDungeonDebugMenu(cmd = nil, **args)
  return nil if !$DEBUG
  return PMDDungeon::DebugMenu.menu if cmd.nil?
  return PMDDungeon::DebugMenu.run(cmd, **args)
end

def pbPMDDungeonDebug
  return pbDungeonDebugMenu
end

module BattleCreationHelperMethods
  class << self
    alias pmd_debug_skip_battle? skip_battle? unless method_defined?(:pmd_debug_skip_battle?)
    def skip_battle?
      return true if $DEBUG && PMDDungeon::DebugMenu.forced_outcome
      return pmd_debug_skip_battle?
    end

    alias pmd_debug_skip_battle skip_battle unless method_defined?(:pmd_debug_skip_battle)
    def skip_battle(outcome_variable, trainer_battle = false)
      forced = $DEBUG ? PMDDungeon::DebugMenu.forced_outcome : nil
      return pmd_debug_skip_battle(outcome_variable, trainer_battle) if !forced
      PMDDungeon::DebugMenu.forced_outcome = nil
      can_lose = $game_temp.battle_rules["canLose"]
      outcome = pmd_debug_skip_battle(outcome_variable, trainer_battle)
      return outcome if forced == :win
      pbSet(outcome_variable, 2)
      pbStartOver if !can_lose
      return 2
    end
  end
end

if defined?(MenuHandlers)
  MenuHandlers.add(:debug_menu, :pmd_dungeon_tools, {
    "name"        => _INTL("PMD dungeon tools..."),
    "parent"      => :main,
    "description" => _INTL("Seeded runs, floors, ally, forced battles, F.O.E./hunter, criminals, bounty, smuggler, reports."),
    "effect"      => proc {
      PMDDungeon::DebugMenu.in_native_menu = true
      begin
        PMDDungeon::DebugMenu.menu
      ensure
        PMDDungeon::DebugMenu.in_native_menu = false
      end
    }
  })
end

EventHandlers.add(:on_frame_update, :pmdmaze_debug_queue, proc { PMDDungeon::DebugMenu.flush_queue if $DEBUG })
