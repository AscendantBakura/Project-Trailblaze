module PMDDungeon
  module EventConfig
    # Max events (items + NPCs + traps) that can spawn on a single floor.
    # Default applied to all dungeons; override with MAX_EVENTS_BY_DUNGEON_AND_FLOOR.
    MAX_EVENTS_PER_FLOOR = 4

    # Per-dungeon, per-floor override for max event count.
    # Format: { dungeon_map_id => { floor => count } }
    # Example: { 108 => { 1..5 => 2, 6..999 => 4 } }
    MAX_EVENTS_BY_DUNGEON_AND_FLOOR = {}

    # Spawn chance (0.0-1.0) for each event type on eligible floors.
    # These determine how often each type is picked when filling up to MAX_EVENTS_PER_FLOOR.
    ITEM_SPAWN_CHANCE = 0.4
    NPC_SPAWN_CHANCE  = 0.3
    TRAP_SPAWN_CHANCE = 0.3

    # Encounter species table used by PMDMaze_EncounterOverride.
    EVENT_POOL = []

    # Default items offered by bribeable NPCs or item quest rewards.
    NPC_ITEM_POOL = [:POTION, :SUPERPOTION, :POKEBALL, :GREATBALL, :ANTIDOTE, :AWAKENING, :PARALYZEHEAL, :SITRUSBERRY]

    # NPC Event pool: supports :type => :outlaw, :nurse, or :quest.
    #
    # Key reference:
    #   :npc              => unique symbol ID
    #   :type             => :outlaw (bribeable criminal), :nurse (heals party), :quest (item request)
    #   :floors           => Integer, Range, Array, or nil for all floors
    #   :unique_run       => if true, only spawns once per dungeon run
    #   :spawn_chance     => 0.0-1.0 probability when eligible
    #   :max_per_floor    => max copies of this NPC rule allowed per floor
    #   :graphic          => character graphic filename from Graphics/Characters/
    #   :dialogue_*       => NPC dialogue strings (varies by type)
    #   :required_item    => (quest only) item symbol or :random to pick from NPC_ITEM_POOL
    #   :reward_item      => (quest only) item symbol given after completing quest
    #
    NPC_POOL = [
      {
        npc: :OUTLAW,
        type: :outlaw,
        floors: 1..999,
        unique_run: false,
        spawn_chance: 0.2,
        graphic: "NPC Goon",
        dialogue_caught: "Now hold on.",
        dialogue_turned_in: "Things were a lot simpler when I was robbing banks with the Deadlock Gang",
        dialogue_after_bribe: "Thanks. Put it on my tab. ",
        dialogue_repeat: "'Gunslinger' never made sense to me. I don't sling guns; I sling bullets. "
      },
      {
        npc: :NURSE,
        type: :nurse,
        floors: 1..999,
        unique_run: false,
        spawn_chance: 0.08,
        graphic: "NPC 16",
        dialogue_before: "Activating healing stream! ",
        dialogue_after: "Ha! Feel stronger? "
      },
      {
        npc: :MERCHANT,
        type: :quest,
        floors: 1..999,
        unique_run: false,
        spawn_chance: 0.15,
        graphic: "NPC 17",
        required_item: :POKEBALL,
        dialogue_no_item: "Pokéball ?",
        dialogue_have_item: "Gimme",
        dialogue_reward: "Thamks.",
        reward_item: :POTION
      }
    ]
  end
end