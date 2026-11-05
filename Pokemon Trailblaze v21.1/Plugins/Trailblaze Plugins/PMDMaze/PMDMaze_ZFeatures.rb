#===============================================================================
# PMDMaze - Dungeon features (Trailblaze restoration)
#   F.O.E., dungeon trainers, hunter, smuggler, item restriction, defeat
#   penalty, bank, bounty board, stealth (grass hiding), treasure rooms and
#   fleeing criminals (bribe/arrest, no battle).
#   Hunger is intentionally NOT implemented.
#===============================================================================
module PMDDungeon
  module Features
    module_function

    def cfg
      return PMDDungeon::FeatureConfig
    end

    def persistent
      $PokemonGlobal.pmdFeatures ||= {}
      return $PokemonGlobal.pmdFeatures
    end

    def run_data
      SeededFloors.run[:features] ||= {}
      return SeededFloors.run[:features]
    end

    def run_active?
      return $PokemonGlobal && SeededFloors.run_active?
    end

    def in_dungeon?
      return false if !run_active? || !$game_map
      return PMDDungeon.dungeon_map_active?
    end

    def floor
      return PMDDungeon.current_floor
    end

    def valid_species(list)
      return list.select { |s| GameData::Species.exists?(s) }
    end

    def valid_items(list)
      return list.select { |i| GameData::Item.exists?(i) }
    end

    def floor_level(bonus = 0)
      base = PMDDungeon.respond_to?(:dungeon_wild_level_for_floor) ? PMDDungeon.dungeon_wild_level_for_floor(floor, 1) : 4 + (floor * 2)
      return [[base + bonus, 1].max, GameData::GrowthRate.max_level].min
    end

    def trainer_type_or_default(type)
      return type if GameData::TrainerType.exists?(type)
      return GameData::TrainerType.keys.first
    end

    #---------------------------------------------------------------------------
    # Run lifecycle
    #---------------------------------------------------------------------------
    def on_run_start(start_floor = nil)
      rd = run_data
      rd[:foe_floor]      = foe_start_floor(start_floor || floor)
      rd[:foe_defeated]   = false
      rd[:foe_species]    = nil
      rd[:foe_steps]      = 0
      rd[:floor_clock]    = nil
      rd[:hunter]         = {}
      rd[:hunter_species] = {}
      rd[:smuggler]       = {}
      rd[:bounty_placed]  = false
      rd[:stored_bag]     = []
      rd[:criminals]      = {}
      rd[:foe_entry]      = nil
      apply_item_restriction
    end

    # The single F.O.E. of a run starts on the bottom floor, or FoeStartDepth
    # floors below the entry when the dungeon has no FloorLimit. A dungeon
    # whose bottom is the entry floor gets no F.O.E.
    def foe_start_floor(start_floor)
      start_floor = start_floor.to_i
      data = PMDDungeon::DataStore.current
      limit = data ? data['FloorLimit'].to_i : 0
      return (limit > start_floor) ? limit : nil if limit > 0
      return start_floor + [PMDDungeon::DataStore.setting(:FeatureConfig, :FOE_START_DEPTH).to_i, 1].max
    end

    def on_run_end
      data = DataStore.current
      if data && data['BGM'] && !data['BGM'].empty? && defined?($game_system) && $game_system
        previous = SeededFloors.run[:previous_bgm]
        previous ? $game_system.bgm_play(previous) : $game_system.bgm_stop
      end
      restore_item_restriction
      set_hidden(false)
    end

    def apply_item_restriction
      return if PMDDungeon::DataStore.setting(:FeatureConfig, :ITEM_RESTRICTION) != :store_all || !$bag
      stored = []
      $bag.pockets.each do |pocket|
        next if !pocket
        pocket.dup.each do |slot|
          item, qty = slot[0], slot[1]
          data = GameData::Item.try_get(item)
          next if !data || data.is_important? || PMDDungeon::DataStore.setting(:FeatureConfig, :ITEM_RESTRICTION_ALLOWED).include?(data.id)
          stored << [data.id, qty]
          $bag.remove(data.id, qty)
        end
      end
      run_data[:stored_bag] = stored
      pbMessage(_INTL("Your items were left at the dungeon entrance for safekeeping.")) if !stored.empty?
    end

    def restore_item_restriction
      stored = run_data[:stored_bag]
      return if !stored || stored.empty? || !$bag
      stored.each { |item, qty| $bag.add(item, qty) }
      run_data[:stored_bag] = []
      pbMessage(_INTL("You collected the items you left at the entrance."))
    end

    #---------------------------------------------------------------------------
    # Floor population (runs inside the seeded generator, before snapshot)
    #---------------------------------------------------------------------------
    def populate_floor(map, fl, layout, sx, sy)
      return if !sx || !sy
      walk = SeededFloors.walkable_proc(map, layout)
      reach = SeededFloors.reachable_from(sx, sy, map.width, map.height, walk)
      occ = SeededFloors.occupied_tiles(map)
      occ[[sx, sy]] = true
      stairs = map.events.values.select { |ev| Layout.stairs?(ev) }.map { |ev| [ev.x, ev.y] }
      tiles = reach.keys.select do |t|
        (t[0] - sx).abs + (t[1] - sy).abs >= 4 && stairs.none? { |s| (s[0] - t[0]).abs + (s[1] - t[1]).abs <= 1 }
      end.sort
      tiles = reach.keys.sort if tiles.empty?
      take = proc { |no_grass = false|
        free = tiles.reject { |t| occ[t] || Layout.reserved_region(Layout.floor_reserved)[t] }
        free = free.reject { |t| Layout.grass_tile?(map, t[0], t[1]) } if no_grass
        next nil if free.empty?
        t = free[rand(free.length)]
        occ[t] = true
        t
      }
      add_data_extras(map, fl, take) if DataStore.bundle
      add_bounty_target(map, fl, take, layout, sx, sy, occ)
      add_trainer(map, fl, take) if fl >= PMDDungeon::DataStore.setting(:FeatureConfig, :TRAINER_MIN_FLOOR) && rand < PMDDungeon::DataStore.setting(:FeatureConfig, :TRAINER_CHANCE)
      add_smuggler(map, fl, take) if fl >= PMDDungeon::DataStore.setting(:FeatureConfig, :SMUGGLER_MIN_FLOOR) && rand < PMDDungeon::DataStore.setting(:FeatureConfig, :SMUGGLER_CHANCE)
      add_criminal(map, fl, take) if fl >= PMDDungeon::DataStore.setting(:FeatureConfig, :CRIMINAL_MIN_FLOOR) && rand < PMDDungeon::DataStore.setting(:FeatureConfig, :CRIMINAL_CHANCE)
      region = Layout.reserved_region(Layout.floor_reserved)
      add_treasure_room(map, fl, reach, occ, tiles.reject { |t| region[t] }) if rand < PMDDungeon::DataStore.setting(:FeatureConfig, :TREASURE_ROOM_CHANCE)
    end

    def add_data_extras(map, fl, take)
      data = DataStore.current
      return unless data
      items = DataStore.rows(data, 'ForcedItem').select { |r| DataStore.covers?(r[0], fl) }.map { |r| [r[1], r[2]] }
      min, max = data.fetch('ExtraItemCount', [0, 0])
      (min + (max > min ? rand(max - min + 1) : 0)).times do
        pool = PMDDungeon::DataStore.setting(:ItemConfig, :ITEM_POOL).select { |r| PMDDungeon.floor_matches?(r[:floors], fl) }
        chosen = DataRuntime.weighted(pool.map { |r| [r, r[:weight] || 1] }, 1)
        items << [chosen[0][:item], 1] if chosen
      end
      local = Hash.new(0)
      map.events.each_value do |event|
        token = event.name.to_s.split('_ITEM_')[1]
        local[token.split('_')[0].to_sym] += 1 if token
      end
      items.each do |item, quantity|
        rule = PMDDungeon::DataStore.setting(:ItemConfig, :ITEM_POOL).find { |r| r[:item] == item }
        rule ||= { item: item, floors: 1..2_147_483_647, rarity: :common }
        counts = $PokemonGlobal.dungeonSpawnedItems
        last = $PokemonGlobal.dungeonLastItemFloor
        next unless PMDDungeon.rule_allowed?(rule, fl, counts, last, local)
        pos = take.call
        next unless pos
        graphic = PMDDungeon::DataStore.setting(:ItemConfig, :ITEM_RARITY_GRAPHIC)[rule[:rarity]][:graphic]
        add_event(map, *pos, '_item_extra', "PMDDungeon::Features.open_chest(@event_id, #{item.inspect}, #{quantity})", character_name: graphic)
        PMDDungeon.mark_rule_usage!(rule, fl, counts, last, local)
      end
      traps = DataStore.rows(data, 'ForcedTrap').select { |r| DataStore.covers?(r[0], fl) }.map { |r| r[1] }
      min, max = data.fetch('ExtraTrapCount', [0, 0])
      pool = PMDDungeon::DataStore.setting(:TrapConfig, :TRAP_POOL).select { |r| PMDDungeon.floor_matches?(r[:floors], fl) }
      (min + (max > min ? rand(max - min + 1) : 0)).times do
        chosen = DataRuntime.weighted(pool.map { |r| [r, r[:weight] || 1] }, 1)
        traps << chosen[0][:id] if chosen
      end
      traps.each do |id|
        next unless pool.any? { |r| r[:id] == id }
        pos = take.call
        next unless pos
        add_event(map, *pos, "_trap_TRAP_#{id}", 'activateTrapEvent', trigger: 1, through: true)
      end
    end

    def add_event(map, x, y, name, script, **opts)
      id = SeededFloors.next_event_id(map)
      map.events[id] = SeededFloors.build_event(id, x, y, name, script, **opts)
      return map.events[id]
    end

    def random_party(fl, count, bonus = 0)
      species = valid_species(PMDDungeon::DataStore.setting(:FeatureConfig, :TRAINER_SPECIES))
      species = [:RATTATA] if species.empty?
      lvl = floor_level(bonus)
      if DataStore.current && !DataStore.rows(DataStore.current, 'TrainerSpecies').empty?
        pool = DataStore.rows(DataStore.current, 'TrainerSpecies')
        return Array.new(count) { [DataRuntime.weighted(pool, 1)[0], lvl] }
      end
      return Array.new(count) { [species[rand(species.length)], lvl] }
    end

    def add_trainer(map, fl, take)
      t = take.call(true)
      return if !t
      pool = PMDDungeon::DataStore.setting(:FeatureConfig, :TRAINERS)
      return if pool.empty?
      info = if DataStore.current
               DataRuntime.weighted(pool.map { |t| [t, t[:weight] || 1] }, 1)[0]
             else
               pool[rand(pool.length)]
             end
      name = info[:names][rand(info[:names].length)]
      count = 1 + (fl / 3).clamp(0, 2)
      if DataStore.current
        base, divisor, cap = DataStore.current.fetch('TrainerPartySize', [1, 3, 3])
        count = [base + fl / divisor, cap].min
        party = DataRuntime.trainer_party(info[:id], fl, count, DataStore.current.fetch('TrainerLevelBonus', 0))
      else
        party = random_party(fl, count)
      end
      script = "PMDDungeon::Features.trainer_event(@event_id, #{info[:type].inspect}, #{name.inspect}, #{party.inspect}, #{info[:version].to_i})"
      add_event(map, t[0], t[1], "Trainer(#{PMDDungeon::DataStore.setting(:FeatureConfig, :TRAINER_SIGHT)})_dungeon_npc", script,
                trigger: 2, character_name: info[:graphic], direction: [2, 4, 6, 8][rand(4)])
    end

    def add_smuggler(map, fl, take)
      t = take.call
      return if !t
      add_event(map, t[0], t[1], "_npc_SMUGGLER", "PMDDungeon::Features.smuggler(@event_id)",
                trigger: 0, character_name: PMDDungeon::DataStore.setting(:FeatureConfig, :SMUGGLER_GRAPHIC))
    end

    def active_bounty
      persistent[:bounties] ||= {}
      PMDDungeon::DataStore.setting(:FeatureConfig, :BOUNTIES).each { |b| return b if persistent[:bounties][b[:id]] == :accepted }
      return nil
    end

    def add_criminal(map, fl, take)
      t = take.call(true)
      return if !t || PMDDungeon::DataStore.setting(:FeatureConfig, :CRIMINALS).empty?
      criminals = PMDDungeon::DataStore.setting(:FeatureConfig, :CRIMINALS)
      idx = if DataStore.current
              chosen = DataRuntime.weighted(criminals.each_with_index.map { |c,i| [i, c[:weight] || 1] }, 1)
              chosen[0]
            else
              rand(criminals.length)
            end
      info = PMDDungeon::DataStore.setting(:FeatureConfig, :CRIMINALS)[idx]
      ev = add_event(map, t[0], t[1], "_npc_CRIMINAL", "PMDDungeon::Features.criminal(@event_id, #{idx})",
                     trigger: 0, character_name: info[:graphic], move_type: 3, speed: 4, freq: 5, step_anime: false)
      data = DataStore.current
      if data
        ev.pages[0].move_speed = data.fetch('CriminalSpeed', 4)
        ev.pages[0].move_frequency = data.fetch('CriminalFrequency', 5)
        ev.pages[0].move_type = 0 if data['CriminalBehaviour'] == :stationary
      end
      ev.pages[0].move_route = flee_route
      return ev
    end

    # Native custom move route: away from player (11), random (9), repeating.
    def flee_route
      route = RPG::MoveRoute.new
      route.repeat = true
      route.skippable = true
      route.list = [11, 11, 9].map { |code| RPG::MoveCommand.new(code, []) } + [RPG::MoveCommand.new(0, [])]
      return route
    end

    def add_bounty_target(map, fl, take, layout = nil, sx = nil, sy = nil, occ = nil)
      b = active_bounty
      return if !b || run_data[:bounty_placed] || !b[:floors].include?(fl)
      if b[:kind] == :defeat
        room = Layout.bounty_room!(map, layout, sx, sy)
        return if !room
        t = room[:center]
        run_data[:bounty_placed] = true
        party = random_party(fl, b[:party_count] || 2, b[:level_bonus] || 3)
        if DataStore.current
          fixed = DataStore.rows(DataStore.current, 'BountyPokemon').select { |r| r[0] == b[:id] }
          party = fixed.map { |r| [r[1], r[2] > 0 ? r[2] : floor_level(b[:level_bonus] || 3)] } unless fixed.empty?
        end
        script = "PMDDungeon::Features.bounty_battle(@event_id, #{b[:id].inspect}, #{party.inspect})"
        ev = add_event(map, t[0], t[1], "Trainer(#{PMDDungeon::DataStore.setting(:FeatureConfig, :TRAINER_SIGHT)})_bounty_npc", script,
                       trigger: 2, character_name: b[:graphic])
        reserved = { rect: room[:rect], entrance: room[:entrance], event_id: ev.id, center: t, seals: room[:seals] }
        Layout.floor_reserved = (Layout.floor_reserved || []) + [reserved]
        room[:seals].each { |id| occ[[map.events[id].x, map.events[id].y]] = true } if occ
        Layout.rect_tiles(room[:rect]).each { |tile| occ[tile] = true } if occ
        intruders = map.events.values.select do |e|
          e.id != ev.id && !Layout.seal?(e) && !Layout.decorative?(e) &&
            (Layout.in_rect?(room[:rect], e.x, e.y) || room[:entrance].include?([e.x, e.y]))
        end
        intruders.each { |e| Layout.relocate!(map, layout, sx, sy, e, Layout.floor_reserved, nil) }
      else
        t = take.call
        return if !t
        run_data[:bounty_placed] = true
        add_event(map, t[0], t[1], "_item_bounty", "PMDDungeon::Features.bounty_found(@event_id, #{b[:id].inspect})",
                  trigger: 0, character_name: b[:graphic])
      end
    end

    def pick_chest_tier
      total = PMDDungeon::DataStore.setting(:FeatureConfig, :TREASURE_CHESTS).sum { |c| c[:weight] }
      roll = rand * total
      PMDDungeon::DataStore.setting(:FeatureConfig, :TREASURE_CHESTS).each do |c|
        return c if roll < c[:weight]
        roll -= c[:weight]
      end
      return PMDDungeon::DataStore.setting(:FeatureConfig, :TREASURE_CHESTS).first
    end

    def add_treasure_room(map, fl, reach, occ, tiles)
      free = tiles.reject { |t| occ[t] }
      return if free.empty?
      center = free[rand(free.length)]
      radius = DataStore.current ? DataStore.current.fetch('TreasureRadius', 2) : 2
      cluster = reach.keys.select { |t| !occ[t] && (t[0] - center[0]).abs <= radius && (t[1] - center[1]).abs <= radius }.sort
      min, max = DataStore.current ? DataStore.current.fetch('TreasureCount', [1, 3]) : [1, 3]
      count = min + rand(max - min + 1)
      cluster.shuffle(random: Random.new(rand(1 << 30))).first(count).each do |t|
        tier = pick_chest_tier
        loot = valid_items(tier[:loot])
        next if loot.empty?
        occ[t] = true
        quantity = 1
        if DataStore.current
          candidates = DataStore.eligible(DataStore.current, 'TreasureItem', 4).select { |r| r[0] == tier[:id] }
          chosen = DataRuntime.weighted(candidates, 2)
          next unless chosen
          item, quantity = chosen[1], chosen[3]
        else
          item = loot[rand(loot.length)]
        end
        add_event(map, t[0], t[1], "_item_chest", "PMDDungeon::Features.open_chest(@event_id, #{item.inspect}, #{quantity})",
                  trigger: 0, character_name: tier[:graphic])
      end
    end

    #---------------------------------------------------------------------------
    # Event scripts
    #---------------------------------------------------------------------------
    def event_for(id)
      return $game_map.events[id]
    end

    def build_trainer(type, name, party, lose_text = nil)
      trainer = NPCTrainer.new(name, trainer_type_or_default(type))
      party.each do |species, level|
        next if !GameData::Species.exists?(species)
        trainer.party << Pokemon.new(species, level, trainer)
      end
      trainer.party << Pokemon.new(:RATTATA, floor_level, trainer) if trainer.party.empty?
      trainer.lose_text = lose_text || _INTL("You got me...")
      return trainer
    end

    def trainer_event(event_id, type, name, party, version = 0)
      ev = event_for(event_id)
      pbExclaim(ev) if ev && defined?(pbExclaim)
      trainer = if DataStore.current && DataStore.current['TrainerPartyMode'] == :pbs
                  pbLoadTrainer(type, name, version)
                else
                  build_trainer(type, name, party)
                end
      if DataStore.current && DataStore.current['TrainerMoneyMode'] == :fixed
        trainer.instance_variable_set(:@pmd_money_base, DataStore.current.fetch('TrainerMoneyBase', 40))
        def trainer.base_money; @pmd_money_base; end
      end
      Portrait.talk(type, _INTL("{1}: Hey! You can't sneak past me!", name), trainer.party[0])
      return if !TrainerBattle.start(trainer)
      ev&.erase
    end

    def bounty_battle(event_id, bounty_id, party)
      b = PMDDungeon::DataStore.setting(:FeatureConfig, :BOUNTIES).find { |x| x[:id] == bounty_id }
      return if !b
      ev = event_for(event_id)
      pbExclaim(ev) if ev && defined?(pbExclaim)
      trainer = build_trainer(b[:trainer_type] || :HOOLIGANS, b[:trainer_name] || b[:name], party)
      Portrait.talk(b[:trainer_type] || :HOOLIGANS,
                    _INTL("{1}: So you're the one hunting me down? Bring it on!", b[:trainer_name] || b[:name]),
                    trainer.party[0])
      return if !TrainerBattle.start(trainer)
      persistent[:bounties][bounty_id] = :done
      pbMessage(_INTL("Bounty complete! Report back to the bounty board."))
      ev&.erase
    end

    #---------------------------------------------------------------------------
    # Fleeing criminals (no battle)
    #---------------------------------------------------------------------------
    def criminal_text(key, argument, fallback)
      row = DataStore.current && DataStore.rows(DataStore.current, 'CriminalText').find { |r| r[0] == key.to_s }
      return fallback unless row
      return argument ? _INTL(row[1], argument) : row[1]
    end

    def criminal_key(event_id)
      return [floor, event_id]
    end

    def criminal_bribe(event_id)
      items = valid_items(PMDDungeon::DataStore.setting(:FeatureConfig, :CRIMINAL_BRIBES))
      return nil if items.empty?
      rng = Random.new(SeededFloors.floor_seed(SeededFloors.run[:seed].to_i + 313, floor, event_id))
      if DataStore.current
        pool = DataStore.eligible(DataStore.current, 'CriminalBribe', 3)
        return nil if pool.empty?
        row = pool.map { |r| r[1] }.uniq.size == 1 ? pool[rng.rand(pool.length)] : DataRuntime.weighted(pool, 1, rng)
        return row[0]
      end
      return items[rng.rand(items.length)]
    end

    def adjust_aura(kind)
      var = (kind == :law) ? PMDDungeon::DataStore.setting(:FeatureConfig, :LAW_VARIABLE) : PMDDungeon::DataStore.setting(:FeatureConfig, :CHAOS_VARIABLE)
      $game_variables[var] = $game_variables[var].to_i + PMDDungeon::DataStore.setting(:FeatureConfig, :AURA_STEP)
      $game_map.need_refresh = true if $game_map
    end

    def criminal(event_id, idx = 0)
      info = PMDDungeon::DataStore.setting(:FeatureConfig, :CRIMINALS)[idx] || PMDDungeon::DataStore.setting(:FeatureConfig, :CRIMINALS)[0]
      rd = run_data
      rd[:criminals] ||= {}
      key = criminal_key(event_id)
      ev = event_for(event_id)
      ev.turn_toward_player if ev && ev.respond_to?(:turn_toward_player)
      Portrait.open(info[:portrait]) do |pt|
        if rd[:criminals][key] == :bribed
          pt.say(criminal_text(:repeat, info[:name], _INTL("{1}: We had a deal, remember? You never saw me.", info[:name])))
          next
        end
        bribe = criminal_bribe(event_id)
        pt.say(criminal_text(:caught, info[:name], _INTL("{1}: Whoa, whoa! No need to make a scene...", info[:name])))
        offer = bribe ? GameData::Item.get(bribe).name : _INTL("nothing")
        cmd = pt.say(criminal_text(:offer, offer, _INTL("Take this {1} and forget you ever saw me?", offer)), [criminal_text(:accept_choice, nil, _INTL("Accept")), criminal_text(:refuse_choice, nil, _INTL("Refuse"))], 2)
        if cmd == 0 && bribe
          quantity = 1
          if DataStore.current
            row = DataStore.eligible(DataStore.current, 'CriminalBribe', 3).find { |r| r[0] == bribe }
            quantity = row[2] if row
          end
          pbReceiveItem(bribe, quantity)
          adjust_aura(:chaos)
          rd[:criminals][key] = :bribed
          ev&.erase if DataStore.current && DataStore.current['CriminalAccept'] == :remove
          pt.say(criminal_text(:accepted, info[:name], _INTL("{1}: Pleasure doing business. I was never here.", info[:name])))
        else
          pt.say(criminal_text(:refused, nil, _INTL("You refused the bribe and signalled the park rangers.")))
          pt.say(criminal_text(:arrested, info[:name], _INTL("{1} was arrested!", info[:name])))
          adjust_aura(:law)
          rd[:criminals][key] = :arrested
          ev&.erase unless DataStore.current && DataStore.current['CriminalRefuse'] == :keep
        end
      end
    end

    def bounty_found(event_id, bounty_id)
      b = PMDDungeon::DataStore.setting(:FeatureConfig, :BOUNTIES).find { |x| x[:id] == bounty_id }
      return if !b
      persistent[:bounties] ||= {}
      persistent[:bounties][bounty_id] = :done
      pbMessage(_INTL("You found the {1}! Report back to the bounty board.", b[:name]))
      event_for(event_id)&.erase
    end

    def open_chest(event_id, item, quantity = 1)
      pbSEPlay("Door exit") rescue nil
      if pbReceiveItem(item, quantity)
        event_for(event_id)&.erase
      else
        pbMessage(_INTL("Your bag is full, so you left the treasure inside."))
      end
    end

    #---------------------------------------------------------------------------
    # Smuggler
    #---------------------------------------------------------------------------
    def smuggler_stock(fl)
      run_data[:smuggler] ||= {}
      fl = :run if DataStore.current && DataStore.current['SmugglerStockScope'] == :run
      return run_data[:smuggler][fl] if run_data[:smuggler][fl]
      rng = Random.new(SeededFloors.floor_seed(SeededFloors.run[:seed].to_i + 77, fl == :run ? 0 : fl, 0))
      pool = PMDDungeon::DataStore.setting(:FeatureConfig, :SMUGGLER_STOCK).select { |item, _| GameData::Item.exists?(item) }
      stock = {}
      size = PMDDungeon::DataStore.setting(:FeatureConfig, :SMUGGLER_STOCK_SIZE)
      rows = DataStore.current && DataStore.eligible(DataStore.current, 'SmugglerItem', 4)
      if rows && rows.map { |r| r[3] }.uniq.size > 1
        candidates = rows.dup
        [size, candidates.size].min.times do
          chosen = DataRuntime.weighted(candidates, 3, rng)
          stock[chosen[0]] = chosen[1]
          candidates.reject! { |r| r[0] == chosen[0] }
        end
      else
        pool.shuffle(random: rng).first(size).each { |item, qty| stock[item] = qty }
      end
      run_data[:smuggler][fl] = stock
      return stock
    end

    def smuggler_price(item)
      if DataStore.current
        row = DataStore.eligible(DataStore.current, 'SmugglerItem', 4).find { |r| r[0] == item }
        return row[2] if row && row[2] > 0
      end
      base = GameData::Item.get(item).price
      base = 100 if base <= 0
      return (base * PMDDungeon::DataStore.setting(:FeatureConfig, :SMUGGLER_PRICE_MULT)).round
    end

    def smuggler(_event_id)
      SmugglerShop.open(smuggler_stock(floor))
    end

    #---------------------------------------------------------------------------
    # Bank and bounty board (town)
    #---------------------------------------------------------------------------
    def bank
      var = PMDDungeon::DataStore.setting(:FeatureConfig, :BANK_VARIABLE)
      loop do
        bal = $game_variables[var].to_i
        cmd = pbMessage(_INTL("Bank balance: ${1}\nWallet: ${2}", bal.to_s_formatted, $player.money.to_s_formatted),
                        [_INTL("Deposit"), _INTL("Withdraw"), _INTL("Cancel")], 3)
        case cmd
        when 0
          max = [$player.money, Settings::MAX_MONEY - bal].min
          if max <= 0
            pbMessage(_INTL("You don't have any money to deposit."))
            next
          end
          amount = choose_amount(_INTL("How much will you deposit?"), max)
          next if amount <= 0
          $player.money -= amount
          $game_variables[var] = bal + amount
          pbMessage(_INTL("Deposited ${1}. Money in the bank is safe if you are defeated in a dungeon.", amount.to_s_formatted))
        when 1
          max = [bal, Settings::MAX_MONEY - $player.money].min
          if max <= 0
            pbMessage(_INTL("There is nothing to withdraw."))
            next
          end
          amount = choose_amount(_INTL("How much will you withdraw?"), max)
          next if amount <= 0
          $player.money += amount
          $game_variables[var] = bal - amount
          pbMessage(_INTL("Withdrew ${1}.", amount.to_s_formatted))
        else
          break
        end
      end
    end

    def choose_amount(message, max)
      params = ChooseNumberParams.new
      params.setRange(0, max)
      params.setDefaultValue(max)
      params.setCancelValue(0)
      return pbMessageChooseNumber(message, params)
    end

    def bounty_board
      persistent[:bounties] ||= {}
      states = persistent[:bounties]
      PMDDungeon::DataStore.setting(:FeatureConfig, :BOUNTIES).each do |b|
        next if states[b[:id]] != :done
        pbMessage(_INTL("Bounty \"{1}\" complete!", b[:name]))
        if b[:reward_money].to_i > 0
          $player.money += b[:reward_money]
          pbMessage(_INTL("You received ${1}.", b[:reward_money].to_s_formatted))
        end
        pbReceiveItem(b[:reward_item], b[:reward_quantity] || 1) if b[:reward_item] && GameData::Item.exists?(b[:reward_item])
        states[b[:id]] = nil
      end
      active = active_bounty
      if active
        cmd = pbMessage(_INTL("Current bounty: {1}\n{2}", active[:name], active[:description]),
                        [_INTL("Keep it"), _INTL("Abandon")], 1)
        if cmd == 1 && pbConfirmMessage(_INTL("Abandon this bounty?"))
          states[active[:id]] = nil
        end
        return
      end
      cmds = PMDDungeon::DataStore.setting(:FeatureConfig, :BOUNTIES).map { |b| _INTL("{1} (F{2}-{3})", b[:name], b[:floors].first, b[:floors].last) }
      cmds << _INTL("Cancel")
      idx = pbMessage(_INTL("Bounty board. Take a job?"), cmds, cmds.length)
      return if idx < 0 || idx >= PMDDungeon::DataStore.setting(:FeatureConfig, :BOUNTIES).length
      b = PMDDungeon::DataStore.setting(:FeatureConfig, :BOUNTIES)[idx]
      pbMessage(b[:description])
      return if !pbConfirmMessage(_INTL("Accept \"{1}\"?", b[:name]))
      states[b[:id]] = :accepted
      pbMessage(_INTL("Bounty accepted. It will turn up on floors {1}-{2} of your next dungeon run.", b[:floors].first, b[:floors].last))
    end

    #---------------------------------------------------------------------------
    # Defeat
    #---------------------------------------------------------------------------
    def handle_defeat(_gameover = false)
      return false if !run_active?
      $stats.blacked_out_count += 1 if $stats
      lost = ($player.money * PMDDungeon::DataStore.setting(:FeatureConfig, :DEFEAT_MONEY_FRACTION)).floor
      $player.money -= lost
      $player.heal_party
      pbMessage("\\w[]\\wm\\c[8]\\l[3]" +
                _INTL("You were overwhelmed in the dungeon and dropped ${1} while escaping...", lost.to_s_formatted))
      pbMessage("\\w[]\\wm\\c[8]\\l[3]" + _INTL("You scurry back home, protecting your exhausted Pokémon."))
      pbCancelVehicles if defined?(pbCancelVehicles)
      Allies.clear_other_followers
      Allies.heal
      $game_switches[Settings::STARTING_OVER_SWITCH] = true
      dest = PMDDungeon::DataStore.setting(:FeatureConfig, :DEFEAT_DESTINATION)
      on_run_end
      SeededFloors.end_run
      PMDDungeon.reset_run_state!
      PMDDungeon.sync_floor_variable
      $game_temp.player_new_map_id    = dest[0]
      $game_temp.player_new_x         = dest[1]
      $game_temp.player_new_y         = dest[2]
      $game_temp.player_new_direction = dest[3] || 2
      pbDismountBike
      $scene.transfer_player if $scene.is_a?(Scene_Map)
      $game_map.refresh
      pbEraseEscapePoint if defined?(pbEraseEscapePoint)
      return true
    end

    #---------------------------------------------------------------------------
    # Stealth
    #---------------------------------------------------------------------------
    def current_tileset_id
      map = $game_map.instance_variable_get(:@map)
      return map ? map.tileset_id : 0
    end

    def hiding_tile?(x, y)
      ranges = PMDDungeon::DataStore.setting(:FeatureConfig, :HIDING_TILE_RANGES)[current_tileset_id] || []
      [0, 1, 2].each do |z|
        tile = $game_map.data[x, y, z] rescue nil
        next if !tile || tile == 0
        return true if ranges.any? { |r| r.include?(tile) }
      end
      tag = $game_map.terrain_tag(x, y)
      num = tag.respond_to?(:id_number) ? tag.id_number : tag.to_i
      return PMDDungeon::DataStore.setting(:FeatureConfig, :HIDING_TERRAIN_TAGS).include?(num)
    end

    def hidden?
      return false if !in_dungeon? || !$game_player
      return $game_temp.pmd_player_hidden ? true : false
    end

    def set_hidden(value)
      return if !$game_temp || !$game_player
      return if ($game_temp.pmd_player_hidden ? true : false) == value
      $game_temp.pmd_player_hidden = value
      $game_player.opacity = value ? PMDDungeon::DataStore.setting(:FeatureConfig, :HIDDEN_OPACITY) : 255
    end

    def update_stealth
      set_hidden(in_dungeon? && hiding_tile?($game_player.x, $game_player.y))
      hidden = hidden?
      $game_map.events.each_value do |ev|
        if ev.respond_to?(:pokemon) && ev.pokemon.respond_to?(:chasing) && hidden && ev.pokemon.chasing
          ev.pokemon.chasing = false
          ev.move_type = 1 if ev.respond_to?(:move_type=)
        end
        next if !ev.instance_variable_get(:@pmd_chaser)
        ev.instance_variable_set(:@move_type, hidden ? 1 : 2)
      end
    end

    #---------------------------------------------------------------------------
    # Live chasers (F.O.E. and hunter)
    #---------------------------------------------------------------------------
    def chaser_present?(tag)
      return $game_map.events.values.any? { |ev| ev.instance_variable_get(:@pmd_chaser) == tag }
    end

    def far_free_tile(min_dist = 8)
      occ = {}
      $game_map.events.each_value { |ev| occ[[ev.x, ev.y]] = true }
      cands = []
      $game_map.width.times do |x|
        $game_map.height.times do |y|
          next if occ[[x, y]] || !$game_map.passable?(x, y, 2)
          d = (x - $game_player.x).abs + (y - $game_player.y).abs
          cands << [x, y, d] if d >= min_dist
        end
      end
      return nil if cands.empty?
      best = cands.max_by { |c| c[2] }
      far = cands.select { |c| c[2] >= best[2] / 2 }
      pick = far[rand(far.length)]
      return [pick[0], pick[1]]
    end

    def spawn_chaser(tag, name, graphic, script, speed, pos = nil)
      return nil if !$scene.is_a?(Scene_Map)
      pos ||= Layout.far_reachable_tile || far_free_tile
      return nil if !pos
      map = $game_map
      id = (map.events.keys.max || 0) + 1
      rpg = SeededFloors.build_event(id, pos[0], pos[1], name, script, trigger: 2,
                                     character_name: graphic, move_type: 2, speed: speed, freq: 6,
                                     step_anime: true)
      ev = Game_Event.new(map.map_id, rpg, map)
      ev.instance_variable_set(:@pmd_live, true)
      ev.instance_variable_set(:@pmd_chaser, tag)
      map.events[id] = ev
      spriteset = $scene.spriteset(map.map_id) rescue nil
      if spriteset && spriteset.respond_to?(:character_sprites)
        spriteset.character_sprites.push(Sprite_Character.new(Spriteset_Map.viewport, ev))
      end
      return ev
    end

    def remove_live(event_id)
      if $game_map.respond_to?(:removeThisEventfromMap)
        $game_map.removeThisEventfromMap(event_id)
      else
        $game_map.events[event_id]&.erase
      end
    end

    def ensure_chasers
      return if !in_dungeon?
      rd = run_data
      foe_due = PMDDungeon::DataStore.setting(:FeatureConfig, :FOE_ENABLED) && !rd[:foe_defeated] &&
                rd[:foe_floor] && rd[:foe_floor] == floor && !chaser_present?(:foe)
      hunter_due = PMDDungeon::DataStore.setting(:FeatureConfig, :HUNTER_ENABLED) && (rd[:hunter] || {})[floor] == :spawned && !chaser_present?(:hunter)
      # No raid plugin: report it once and spawn nothing (never a normal battle).
      return if (foe_due || hunter_due) && !raid_available?(true)
      if foe_due
        rd[:foe_species] ||= pick_raid_species(:foe)
        pos = rd[:foe_entry] ? Layout.tile_beside_stairs(rd[:foe_entry]) : nil
        ev = spawn_chaser(:foe, "FOE_danger", chaser_graphic(:foe, rd[:foe_species]), "PMDDungeon::Features.foe_battle(@event_id)",
                          PMDDungeon::DataStore.setting(:FeatureConfig, :FOE_MOVE_SPEED), pos)
        rd[:foe_entry] = nil if ev
      end
      if hunter_due
        rd[:hunter_species] ||= {}
        rd[:hunter_species][floor] ||= pick_raid_species(:hunter)
        spawn_chaser(:hunter, "hunter_danger", chaser_graphic(:hunter, rd[:hunter_species][floor]),
                     "PMDDungeon::Features.hunter_battle(@event_id)", PMDDungeon::DataStore.setting(:FeatureConfig, :HUNTER_MOVE_SPEED))
      end
    end

    # F.O.E.s and hunters are Pokémon: "auto" (or blank) uses the follower
    # sprite of the species picked for the chaser.
    def chaser_graphic(kind, species)
      graphic = PMDDungeon::DataStore.setting(:FeatureConfig, (kind == :foe) ? :FOE_GRAPHIC : :HUNTER_GRAPHIC).to_s
      return graphic if !graphic.empty? && graphic.downcase != "auto"
      return species ? "Followers/#{species}" : ""
    end

    #---------------------------------------------------------------------------
    # Hunter clock: seconds spent on the current floor (paused during menus,
    # messages, cutscenes and battles). It restarts whenever the floor changes.
    #---------------------------------------------------------------------------
    def floor_clock
      rd = run_data
      clock = rd[:floor_clock]
      rd[:floor_clock] = clock = { floor: floor, seconds: 0.0 } if !clock.is_a?(Hash) || clock[:floor] != floor
      return clock
    end

    def floor_seconds
      return floor_clock[:seconds]
    end

    def tick_floor_clock(delta)
      return if !in_dungeon? || delta <= 0
      clock = floor_clock
      clock[:seconds] += [delta, 0.5].min
    end

    def hunter_check
      rd = run_data
      return if !PMDDungeon::DataStore.setting(:FeatureConfig, :HUNTER_ENABLED)
      return if floor < PMDDungeon::DataStore.setting(:FeatureConfig, :HUNTER_MIN_FLOOR)
      return if floor_seconds < PMDDungeon::DataStore.setting(:FeatureConfig, :HUNTER_SECONDS)
      rd[:hunter] ||= {}
      return if !rd[:hunter][floor].nil?
      rd[:hunter][floor] = :spawned
      pbMessage(_INTL("You've lingered too long... Something is hunting you on this floor!"))
    end

    def on_step
      return if !in_dungeon?
      rd = run_data
      update_stealth
      floor_clock
      if PMDDungeon::DataStore.setting(:FeatureConfig, :FOE_ENABLED) && rd[:foe_floor] && !rd[:foe_defeated]
        rd[:foe_steps] = rd[:foe_steps].to_i + 1
        if rd[:foe_steps] >= PMDDungeon::DataStore.setting(:FeatureConfig, :FOE_CLIMB_STEPS) && rd[:foe_floor] != floor
          rd[:foe_steps] = 0
          route = Layout.cross_floor_route(rd[:foe_floor], floor)
          rd[:foe_floor] += (rd[:foe_floor] > floor) ? -1 : 1
          rd[:foe_entry] = route[:entry] if rd[:foe_floor] == floor
          if rd[:foe_floor] == floor
            pbMessage(_INTL("A chill runs down your spine... The F.O.E. has climbed onto this floor!"))
          elsif (rd[:foe_floor] - floor).abs == 1
            pbMessage(_INTL("You hear something heavy moving one floor away..."))
          end
        end
      end
      hunter_check
      ensure_chasers
    end

    def on_enter_floor
      return if !in_dungeon?
      floor_clock
      $game_temp.pmd_player_hidden = false
      $game_player.opacity = 255
      ensure_chasers
    end

    def foe_battle(event_id)
      return if !raid_available?(true)
      pbMessage(_INTL("The F.O.E. attacks!"))
      boss, rules = raid_boss(:foe, run_data[:foe_species])
      decision = start_raid(:foe, boss, rules)
      return if !raid_won?(event_id, decision) || !in_dungeon?
      remove_live(event_id)
      rd = run_data
      rd[:foe_defeated] = true
      rd[:foe_floor] = nil
      rd[:foe_entry] = nil
      rd[:foe_steps] = 0
      pbMessage(_INTL("The F.O.E. was defeated! It won't trouble you again in this dungeon."))
    end

    def hunter_battle(event_id)
      return if !raid_available?(true)
      species = (run_data[:hunter_species] || {})[floor]
      boss, rules = raid_boss(:hunter, species)
      pbMessage(_INTL("The {1} {2} found you! It won't let you get away!",
                      PMDDungeon::DataStore.setting(:FeatureConfig, :HUNTER_NAME), boss.name))
      decision = start_raid(:hunter, boss, rules)
      return if !raid_won?(event_id, decision) || !in_dungeon?
      remove_live(event_id)
      run_data[:hunter] ||= {}
      run_data[:hunter][floor] = :beaten
    end

    #---------------------------------------------------------------------------
    # Raid battles ([DBK] Raid Battles plugin) for the F.O.E. and the hunter
    #---------------------------------------------------------------------------
    # Raid boss setup only: ensures the PMD rules (no capture, no running) are
    # applied after the raid plugin's own prepare_battle, which forces raid
    # style capture on.
    module RaidBattleSetup
      def prepare_battle(battle)
        super
        PMDDungeon::Features.apply_raid_battle_rules(battle)
      end
    end

    def raid_context
      return @raid_context
    end

    def last_raid
      return @last_raid
    end

    def raid_available?(announce = false)
      ok = defined?(::RaidBattle) && ::RaidBattle.respond_to?(:start) &&
           defined?(::Pokemon) && ::Pokemon.method_defined?(:setRaidBossAttributes) &&
           defined?(::GameData::RaidType) ? true : false
      return true if ok
      if !@raid_missing_logged
        @raid_missing_logged = true
        echoln("PMDMaze: F.O.E./hunter raids need the [DBK] Raid Battles plugin (RaidBattle.start); it is not loaded.") if defined?(echoln)
      end
      if announce && run_active? && !run_data[:raid_missing_reported]
        run_data[:raid_missing_reported] = true
        pbMessage(_INTL("Error: the Raid Battles plugin is missing, so the F.O.E. and hunters cannot battle."))
      end
      return false
    end

    def install_raid_hooks!
      return if @raid_hooks_installed
      BattleCreationHelperMethods.singleton_class.prepend(RaidBattleSetup)
      @raid_hooks_installed = true
    end

    def raid_config(kind)
      return (kind == :foe) ? PMDDungeon::DataStore.setting(:FeatureConfig, :FOE_RAID) : PMDDungeon::DataStore.setting(:FeatureConfig, :HUNTER_RAID)
    end

    def raid_rules(kind)
      rc = raid_config(kind)
      rules = { rank: rc[:rank], style: rc[:style], turn_count: rc[:turn_count], ko_count: rc[:ko_count],
                shield_hp: rc[:shield_hp], extra_actions: rc[:extra_actions].dup }
      partner = Allies.raid_partner_rule
      rules[:partner] = partner if partner
      return rules
    end

    def raid_species_pool(kind)
      rc = raid_config(kind)
      return valid_species(rc[:species]).select { |s| GameData::Species.get(s).raid_species?(rc[:style]) }
    end

    def pick_raid_species(kind)
      pool = raid_species_pool(kind)
      return pool.empty? ? nil : pool[rand(pool.length)]
    end

    # Builds the boss Pokemon with the plugin's own raid boss attributes (HP
    # scaling, immunities, raid moves, IVs) for the configured rank. A species
    # chosen when the chaser spawned is kept so the battle matches its sprite.
    def raid_boss(kind, species = nil)
      rc = raid_config(kind)
      pool = raid_species_pool(kind)
      raise ArgumentError, "PMDMaze: no raid species for #{kind} in #{rc[:species].inspect}" if pool.empty?
      species = pool[rand(pool.length)] if !species || !pool.include?(species)
      rules = raid_rules(kind)
      pkmn = Pokemon.new(species, floor_level(rc[:level_bonus]))
      pkmn.setRaidBossAttributes(rules)
      return pkmn, rules
    end

    # Runs RaidBattle.start and returns the battle decision reported through
    # :on_wild_battle_end (nil if the battle never reported one).
    def start_raid(kind, boss = nil, rules = nil)
      raise "PMDMaze: RaidBattle.start is not available" if !raid_available?
      install_raid_hooks!
      boss, rules = raid_boss(kind) if !boss
      @raid_context = { kind: kind, decision: nil, prepared: false, pokemon: boss, rules: rules,
                        partner: rules[:partner] }
      setBattleRule("cannotRun")
      begin
        ::RaidBattle.start(boss, rules)
      ensure
        @last_raid = @raid_context
        @raid_context = nil
        Allies.clear_raid_partner
      end
      return @last_raid[:decision]
    end

    def apply_raid_battle_rules(battle)
      ctx = @raid_context
      return if !ctx
      battle.raidStyleCapture = false if battle.respond_to?(:raidStyleCapture=)
      battle.disablePokeBalls = true if battle.respond_to?(:disablePokeBalls=)
      battle.canRun = false if battle.respond_to?(:canRun=)
      ctx[:prepared] = true
      ctx[:can_lose] = battle.canLose if battle.respond_to?(:canLose)
    end

    def note_raid_outcome(decision)
      @raid_context[:decision] = decision if @raid_context
    end

    # 1 = boss defeated. Loss/draw (2/5) and being blown out of the raid (3:
    # turn or KO limit) are dungeon defeats (the raid sets canLose, so the
    # native black-out never runs). Abort (0/nil) and capture (4, disabled)
    # are not victories; the chaser is pushed away so it can't re-trigger.
    def raid_won?(event_id, decision)
      case decision
      when 1
        return true
      when 2, 3, 5
        handle_defeat
      else
        pos = Layout.far_reachable_tile || far_free_tile
        ev = $game_map&.events&.[](event_id)
        ev.moveto(pos[0], pos[1]) if ev && pos && ev.respond_to?(:moveto)
      end
      return false
    end

    #---------------------------------------------------------------------------
    # Hooks that must wrap methods defined by plugins loaded after this one
    #---------------------------------------------------------------------------
    def install_late_hooks!
      return if @late_hooks_installed
      @late_hooks_installed = true
      Object.class_eval do
        alias_method :pmd_features_pbStartOver, :pbStartOver
        def pbStartOver(*args)
          return if PMDDungeon::Features.handle_defeat(*args)
          pmd_features_pbStartOver(*args)
        end
        alias_method :pmd_features_pbEventCanReachPlayer?, :pbEventCanReachPlayer?
        def pbEventCanReachPlayer?(event, player, distance)
          return false if PMDDungeon::Features.hidden?
          return pmd_features_pbEventCanReachPlayer?(event, player, distance)
        end
        alias_method :pmd_features_pbBattleOnStepTaken, :pbBattleOnStepTaken
        def pbBattleOnStepTaken(*args)
          return if PMDDungeon::Features.hidden?
          pmd_features_pbBattleOnStepTaken(*args)
        end
        if private_method_defined?(:pbSpawnOnStepTaken) || method_defined?(:pbSpawnOnStepTaken)
          alias_method :pmd_features_pbSpawnOnStepTaken, :pbSpawnOnStepTaken
          def pbSpawnOnStepTaken(*args)
            return if PMDDungeon::Features.hidden?
            pmd_features_pbSpawnOnStepTaken(*args)
          end
        end
      end
      Battle.class_eval do
        alias_method :pmd_features_pbLoseMoney, :pbLoseMoney
        def pbLoseMoney
          return if PMDDungeon::Features.run_active?
          pmd_features_pbLoseMoney
        end
      end
    end
  end
end

class PokemonGlobalMetadata
  attr_writer :pmdFeatures

  def pmdFeatures
    @pmdFeatures ||= {}
    return @pmdFeatures
  end
end

class Game_Temp
  attr_accessor :pmd_player_hidden
end

class Game_Event
  def pmd_live?
    return @pmd_live ? true : false
  end
end

EventHandlers.add(:on_player_step_taken, :pmdmaze_features, proc { PMDDungeon::Features.on_step })
EventHandlers.add(:on_wild_battle_end, :pmdmaze_raid_outcome,
  proc { |_species, _level, decision| PMDDungeon::Features.note_raid_outcome(decision) }
)
EventHandlers.add(:on_enter_map, :pmdmaze_features, proc { |_old| PMDDungeon::Features.on_enter_floor })
EventHandlers.add(:on_frame_update, :pmdmaze_features_late_hooks,
  proc {
    PMDDungeon::Features.install_late_hooks!
    now = defined?(System) && System.respond_to?(:uptime) ? System.uptime : Time.now.to_f
    last = $pmd_floor_clock_last
    $pmd_floor_clock_last = now
    if $game_map && $scene.is_a?(Scene_Map) && !$game_temp.in_menu && !$game_temp.in_battle &&
       !pbMapInterpreterRunning? && !($game_temp.respond_to?(:message_window_showing) && $game_temp.message_window_showing)
      PMDDungeon::Features.tick_floor_clock(now - last) if last && PMDDungeon::Features.run_active?
      PMDDungeon::Features.ensure_chasers if Graphics.frame_count % 40 == 0
    end
  }
)
