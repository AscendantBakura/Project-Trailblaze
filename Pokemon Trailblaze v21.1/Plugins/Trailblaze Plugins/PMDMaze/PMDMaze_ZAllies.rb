#===============================================================================
# PMDMaze - Recruitable ally (Trailblaze restoration)
#   * PMDDungeon::Allies.recruit(@event_id, :HILDA) from a town event (not the
#     dungeon entrance). The ally becomes a native follower (Followers.add,
#     stored in $PokemonGlobal.followers so it survives map transfers and
#     saves) and a native partner trainer ($PokemonGlobal.partner) with its own
#     party, so battles become double battles (2v1 against a single foe) with
#     the ally's own back sprite and Pokemon.
#   * Talking to the ally (FollowerData#interact) offers keep / team / part.
#   * Parting ways restores the recruit event (self switch A off).
#   * Dungeon defeats and pbStartOver keep the ally.
#===============================================================================
module PMDDungeon
  module Allies
    module_function

    def cfg
      return PMDDungeon::FeatureConfig
    end

    def follower_name
      return PMDDungeon::DataStore.setting(:FeatureConfig, :ALLY_FOLLOWER_NAME)
    end

    def info(id)
      return PMDDungeon::DataStore.setting(:FeatureConfig, :ALLIES)[id]
    end

    def state
      return $PokemonGlobal&.pmdAlly
    end

    def active?
      return state ? true : false
    end

    def dungeon_partner_allowed?
      return false if !$PokemonGlobal || !SeededFloors.run_active? || !$game_map
      return false if @suspend_partner
      if DataStore.bundle
        id = SeededFloors.run[:dungeon_id] || DataStore.dungeon_id(SeededFloors.run[:map] || $game_map.map_id)
        dungeon = DataStore.bundle['pmd_dungeons'][id]
        return dungeon && dungeon['MapIDs'].include?($game_map.map_id)
      end
      return PMDDungeon.dungeon_map_active?
    end

    def owned_partner?(partner = $PokemonGlobal&.partner)
      data = state && info(state[:id])
      return data && partner && partner[0] == data[:trainer_type] && partner[1] == data[:name]
    end

    def sync_partner
      return if !state
      partner = $PokemonGlobal.partner
      state[:partner] ||= partner if owned_partner?(partner)
      state[:partner] ||= partner_array(state[:id])
      normalize_partner(state[:partner])
      normalize_partner(partner) if owned_partner?(partner)
      if dungeon_partner_allowed?
        $PokemonGlobal.partner = state[:partner] if !partner || owned_partner?(partner)
      elsif owned_partner?(partner)
        state[:partner] = partner
        $PokemonGlobal.partner = nil
      end
    end

    def partner_active?
      sync_partner
      return !!(dungeon_partner_allowed? && owned_partner?)
    end

    def live_party
      sync_partner
      return state && state[:partner] ? state[:partner][3] : []
    end

    def dialogue(id, key, fallback)
      record = DataStore.bundle && DataStore.bundle['pmd_companions'][id]
      return record[key] if record && record.key?(key)
      return fallback
    end

    def say(pt, id, key, fallback = "")
      text = dialogue(id, key, fallback)
      pt.say(text) if text && !text.empty?
    end

    def target_level(id)
      data = info(id)
      best = ($player&.party || []).map(&:level).max || 1
      lvl = [best + data[:level_offset].to_i, data[:min_level].to_i, 1].max
      return [lvl, GameData::GrowthRate.max_level].min
    end

    def build_party(id)
      data = info(id)
      record = DataStore.bundle && DataStore.bundle['pmd_companions'][id]
      if record && record['PartyMode'] == :pbs
        return pbLoadTrainer(data[:trainer_type], data[:name], record['TrainerVersion'] || 0)
      end
      trainer = NPCTrainer.new(data[:name], data[:trainer_type])
      lvl = target_level(id)
      entries = record ? DataStore.rows(record, 'Pokemon') : data[:party].map { |species| [species, 0] }
      trainer.party = entries.select { |species,_level| GameData::Species.exists?(species) }.map do |species,level|
        Pokemon.new(species, level > 0 ? level : lvl, trainer)
      end
      return trainer
    end

    # Same shape as Essentials' pbRegisterPartner: [type, name, id, party, items].
    def partner_array(id)
      trainer = build_party(id)
      return [trainer.trainer_type, trainer.name, trainer.id, trainer.party, (trainer.items || []).clone]
    end

    def normalize_partner(partner)
      partner[4] ||= [] if partner.is_a?(Array) && partner.length >= 4
      return partner
    end

    def register_partner(id)
      partner = partner_array(id)
      state[:partner] = partner if state
      $PokemonGlobal.partner = partner if dungeon_partner_allowed? && !$PokemonGlobal.partner
      return partner
    end

    def sync_levels
      return if !partner_active?
      lvl = target_level(state[:id])
      record = DataStore.bundle && DataStore.bundle['pmd_companions'][state[:id]]
      return if record && record['PartyMode'] == :pbs
      $PokemonGlobal.partner[3].each_with_index do |pkmn, index|
        next if record && DataStore.rows(record, 'Pokemon')[index] && DataStore.rows(record, 'Pokemon')[index][1] > 0
        next if pkmn.level >= lvl
        pkmn.level = lvl
        pkmn.calc_stats
      end
    end

    def heal
      return if !state
      live_party.each(&:heal)
    end

    # Raid battles (RaidBattle.start) deregister the partner and re-register it
    # from PBS with pbRegisterPartner(type, name, id). The ally has no PBS entry,
    # so the live partner array (her own team, levels, HP) is remembered here
    # and handed back by the pbRegisterPartner hook below. The 4th element
    # (true) tells the raid plugin not to rescale the partner.
    def raid_partner_rule
      return nil if !partner_active?
      sync_levels
      @raid_partner = $PokemonGlobal.partner
      return [@raid_partner[0], @raid_partner[1], @raid_partner[2], true]
    end

    def take_raid_partner(tr_type, tr_name, tr_id)
      p = @raid_partner
      return nil if !p || p[0] != tr_type || p[1] != tr_name || p[2] != tr_id
      return nil unless dungeon_partner_allowed?
      normalize_partner(p)
      $PokemonGlobal.partner = p
      state[:partner] = p if state
      return p
    end

    def raid_partner_pending?
      return @raid_partner ? true : false
    end

    def clear_raid_partner
      @raid_partner = nil
    end

    def follower_data
      return $PokemonGlobal.followers.find { |f| f.name == follower_name }
    end

    def recruit(event_id, id)
      data = info(id)
      return false if !data
      if PMDDungeon.respond_to?(:dungeon_map_active?) && PMDDungeon.dungeon_map_active?
        pbMessage(dialogue(id, 'DungeonRecruitMessage', _INTL("{1}: Let's talk once we're back in town.", data[:name])))
        return false
      end
      lead = data[:party].find { |s| GameData::Species.exists?(s) }
      Portrait.open(data[:trainer_type], lead) do |pt|
        if active?
          say(pt, id, 'AlreadyFollowingMessage', _INTL("{1}: Looks like you already have a partner.", data[:name]))
          next false
        end
        say(pt, id, 'AskMessage', _INTL("{1}: Heading into the dungeon? It's dangerous to go alone.", data[:name]))
        question = dialogue(id, 'ConfirmMessage', _INTL("Travel together with {1}?", data[:name]))
        choices = [dialogue(id, 'AcceptChoice', _INTL("Yes")), dialogue(id, 'DeclineChoice', _INTL("No"))]
        if !pt.confirm(question, choices)
          say(pt, id, 'DeclineMessage')
          next false
        end
        join(id, event_id)
        say(pt, id, 'AcceptMessage', _INTL("{1}: Great! My Pok\u00e9mon and I will fight right beside yours.", data[:name]))
        next true
      end
    end

    # Adds the follower + partner. event_id is a map event on the current map;
    # nil creates a temporary event at the player (debug).
    def join(id, event_id = nil)
      data = info(id)
      partner = partner_array(id)
      temp = nil
      if event_id.nil? || !$game_map.events[event_id]
        temp = temporary_event(data)
        event_id = temp.id
      end
      Followers.add(event_id, follower_name, nil)
      follower_data.character_name = data[:charset] if follower_data.respond_to?(:character_name=)
      if temp
        $game_map.events.delete(temp.id)
        $PokemonGlobal.pmdAlly = { id: id, source: nil, partner: partner, flavour_cooldown: 0 }
      else
        $game_self_switches[[$game_map.map_id, event_id, "A"]] = true
        $PokemonGlobal.pmdAlly = { id: id, source: [$game_map.map_id, event_id], partner: partner, flavour_cooldown: 0 }
      end
      $game_map.need_refresh = true
      sync_partner
      return true
    end

    def temporary_event(data)
      id = ($game_map.events.keys.max || 0) + 1
      rpg = RPG::Event.new($game_player.x, $game_player.y)
      rpg.id = id
      rpg.name = follower_name
      rpg.pages[0].graphic.character_name = data[:charset]
      ev = Game_Event.new($game_map.map_id, rpg, $game_map)
      ev.instance_variable_set(:@pmd_live, true)
      $game_map.events[id] = ev
      return ev
    end

    def talk
      s = state
      return if !s
      data = info(s[:id])
      lead = live_party.first
      Portrait.open(data[:trainer_type], lead) do |pt|
        id = s[:id]
        record = DataStore.bundle && DataStore.bundle['pmd_companions'][id]
        lines = record && record.key?('TalkMessage') ? record['TalkMessage'].map(&:first) : [_INTL("{1}: What's up?", data[:name])]
        greeting = lines.empty? ? "" : lines[rand(lines.length)]
        cmd = pt.say(greeting,
                     [dialogue(id, 'KeepChoice', _INTL("Keep going")), dialogue(id, 'TeamChoice', _INTL("Your team")), dialogue(id, 'DismissChoice', _INTL("Part ways"))], 0)
        case cmd
        when 1
          party = live_party
          text = party.map { |p| _INTL("{1} Lv.{2} ({3}/{4} HP)", p.name, p.level, p.hp, p.totalhp) }.join("\n")
          pt.say(text.empty? ? _INTL("...") : text)
        when 2
          if pt.confirm(dialogue(id, 'DismissConfirm', _INTL("Part ways with {1}?", data[:name])),
                        [dialogue(id, 'DismissAcceptChoice', _INTL("Yes")), dialogue(id, 'DismissDeclineChoice', _INTL("No"))])
            say(pt, id, 'DismissMessage', _INTL("{1}: Okay. You know where to find me.", data[:name]))
            dismiss
          else
            say(pt, id, 'DismissCancelMessage')
          end
        else
          say(pt, id, 'KeepMessage', _INTL("{1}: Right behind you!", data[:name]))
        end
      end
    end

    def dismiss
      s = state
      return false if !s
      Followers.remove(follower_name)
      pbDeregisterPartner if owned_partner?
      if s[:source]
        $game_self_switches[[s[:source][0], s[:source][1], "A"]] = false
      end
      $PokemonGlobal.pmdAlly = nil
      $game_map.need_refresh = true if $game_map
      return true
    end

    # Removes every follower except the ally (dungeon defeat).
    def clear_other_followers
      names = $PokemonGlobal.followers.map(&:name).uniq - [follower_name]
      if !active?
        Followers.clear
        return
      end
      names.each { |n| Followers.remove(n) }
      pbDeregisterPartner if $PokemonGlobal.partner && !partner_active?
    end

    def keep_on_clear?
      return @keep_on_clear && active?
    end

    def keep_on_clear(value)
      @keep_on_clear = value
    end

    def suspend_partner(value)
      @suspend_partner = value
      sync_partner
    end

    def flavour_config
      return nil unless state && DataStore.bundle
      base = DataStore.bundle['pmd_companions'][state[:id]]
      return nil unless base
      if dungeon_partner_allowed?
        id = SeededFloors.run[:dungeon_id] || DataStore.dungeon_id($game_map.map_id)
        scoped = DataStore.bundle['pmd_companions']["#{state[:id]}@#{id}".to_sym]
        return base.merge(scoped) if scoped
      end
      return base
    end

    def flavour_step
      sync_partner
      config = flavour_config
      return unless config && config['FlavourChance'].to_f > 0 && !DataStore.rows(config, 'FlavourMessage').empty?
      return if !$scene || !defined?(Scene_Map) || !$scene.is_a?(Scene_Map)
      return if defined?(pbMapInterpreterRunning?) && pbMapInterpreterRunning?
      return if $game_temp && [:in_menu, :in_battle, :message_window_showing, :player_transferring, :transition_processing].any? { |key| $game_temp.respond_to?(key) && $game_temp.send(key) }
      return if defined?($game_message) && $game_message && $game_message.respond_to?(:busy?) && $game_message.busy?
      return if @speaking
      cooldown = state[:flavour_cooldown].to_i
      if cooldown > 0
        state[:flavour_cooldown] = cooldown - 1
        return
      end
      return if rand >= config['FlavourChance']
      lines = config['FlavourMessage']
      state[:flavour_cooldown] = config.fetch('FlavourCooldown', 250)
      begin
        @speaking = true
        pbMessage(lines[rand(lines.length)][0])
      ensure
        @speaking = false
      end
    end

    def asset_paths(id)
      data = info(id)
      paths = {
        trainer_front: "Graphics/Trainers/#{data[:trainer_type]}",
        trainer_back:  "Graphics/Trainers/#{data[:trainer_type]}_back",
        charset:       "Graphics/Characters/#{data[:charset]}"
      }
      data[:party].each do |s|
        paths[:"#{s}_front"] = "Graphics/Pokemon/Front/#{s}"
        paths[:"#{s}_back"]  = "Graphics/Pokemon/Back/#{s}"
      end
      return paths
    end

    def asset_report
      lines = []
      PMDDungeon::DataStore.setting(:FeatureConfig, :ALLIES).each_key do |id|
        asset_paths(id).each do |key, path|
          file = pbResolveBitmap(path)
          if !file
            lines << "MISSING #{id} #{key}: #{path}"
            next
          end
          bmp = Bitmap.new(file)
          frames = (bmp.width > bmp.height * 2) ? bmp.width / bmp.height : 1
          frames = bmp.width / 180 if key == :trainer_back && bmp.height == 160
          lines << "#{frames > 1 || key == :charset ? 'ok' : 'STATIC'} #{id} #{key}: #{path} #{bmp.width}x#{bmp.height}"
          bmp.dispose
        end
      end
      return lines
    end
  end
end

class PokemonGlobalMetadata
  attr_accessor :pmdAlly
end

class FollowerData
  alias pmd_ally_interact interact unless method_defined?(:pmd_ally_interact)
  def interact(event)
    if @name == PMDDungeon::DataStore.setting(:FeatureConfig, :ALLY_FOLLOWER_NAME)
      return if pbMapInterpreterRunning?
      event&.turn_toward_player
      pbMapInterpreter.setup([RPG::EventCommand.new(355, 0, ["PMDDungeon::Allies.talk"]),
                              RPG::EventCommand.new(0, 0, [])], 0)
      return
    end
    pmd_ally_interact(event)
  end
end

module Followers
  class << self
    alias pmd_ally_clear clear unless method_defined?(:pmd_ally_clear)
    def clear
      return pmd_ally_clear if !PMDDungeon::Allies.keep_on_clear?
      PMDDungeon::Allies.clear_other_followers
    end
  end
end

module BattleCreationHelperMethods
  class << self
    alias pmd_ally_partner_can_participate? partner_can_participate? unless method_defined?(:pmd_ally_partner_can_participate?)
    def partner_can_participate?(foe_party)
      PMDDungeon::Allies.sync_partner
      if PMDDungeon::Allies.partner_active? && !$game_temp.battle_rules["noPartner"]
        PMDDungeon::Allies.sync_levels
        setBattleRule("2v1") if $game_temp.battle_rules["size"].nil? && foe_party.length == 1
      end
      return pmd_ally_partner_can_participate?(foe_party)
    end
  end
end

alias pmd_ally_pbRegisterPartner pbRegisterPartner unless defined?(pmd_ally_pbRegisterPartner)
def pbRegisterPartner(tr_type, tr_name, tr_id = 0)
  return if PMDDungeon::Allies.take_raid_partner(tr_type, tr_name, tr_id)
  pmd_ally_pbRegisterPartner(tr_type, tr_name, tr_id)
end

alias pmd_ally_pbStartOver pbStartOver unless defined?(pmd_ally_pbStartOver)
def pbStartOver(*args)
  PMDDungeon::Allies.keep_on_clear(true)
  PMDDungeon::Allies.heal
  PMDDungeon::Allies.suspend_partner(true)
  begin
    return pmd_ally_pbStartOver(*args)
  ensure
    PMDDungeon::Allies.keep_on_clear(false)
    PMDDungeon::Allies.suspend_partner(false)
    PMDDungeon::Allies.sync_partner
  end
end
