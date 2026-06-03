module PMDDungeon
  module TrapConfig
    # Example:
    # DEFAULT_TRAP_COUNT = 2
    DEFAULT_TRAP_COUNT = 0

    # Example:
    # TRAP_COUNT_BY_FLOOR = {
    #   2 => 1,
    #   3 => 2
    # }
    TRAP_COUNT_BY_FLOOR = {}

    # Example:
    # FORCED_TRAPS_BY_FLOOR = {
    #   4 => [:EXPLOSION]
    # }
    FORCED_TRAPS_BY_FLOOR = {}

    # Status immunities used by :status traps.
    # Pokémon matching any listed type are never targeted by that status.
    STATUS_TYPE_IMMUNITIES = {
      :BURN      => [:FIRE],
      :POISON    => [:POISON, :STEEL],
      :PARALYSIS => [:ELECTRIC],
      :FROZEN    => [:ICE],
      :FROSTBITE => [:ICE],
      :SLEEP     => []
    }

    # Trap pool for random dungeon floors.
    # Shared keys:
    #   :id            => unique symbol (required, used for forced traps)
    #   :type          => trap behavior type (see below)
    #   :floors        => Integer, Range, Array, or nil for any floor
    #   :weight        => spawn weight (higher = more common)
    #   :graphic       => character graphic filename (shown when triggered)
    #   :message       => dialogue shown when trap activates
    #   :disappears    => if true, trap vanishes after triggering once
    #
    # Type-specific keys:
    #   :type => :status  -> :status (symbol: :BURN, :POISON, :PARALYSIS, :SLEEP, :FROZEN, :FROSTBITE)
    #   :type => :explosion  -> no extra keys (10% max-HP damage to all, Damp blocks it)
    #   :type => :pp_down    -> no extra keys (20% PP reduction on random party member)
    #   :type => :spikes     -> no extra keys (5% max-HP damage, ignores raised Pokémon)
    #   :type => :teleport_room  -> no extra keys (warps player away 5+ tiles)
    #   :type => :floor_shift    -> :direction (:up or :down)
    #   :type => :miniboss       -> :species (symbol), :level (integer)
    #
    # Example pool (status trap + miniboss):
    # TRAP_POOL = [
    #   {
    #     id: :FLAME_TRAP,
    #     type: :status,
    #     floors: 1..99,
    #     weight: 8,
    #     status: :BURN,
    #     graphic: "Dungeon Trap Flamethrower",
    #     message: "Scorching heat erupts around you!",
    #     disappears: false
    #   },
    # ]
    TRAP_POOL = [
      {
        id: :BURN_TRAP,
        type: :status,
        floors: 1..999,
        weight: 10,
        status: :BURN,
        graphic: "Dungeon Trap Flamethrower",
        message: "Burn!",
        disappears: false
      },
      {
        id: :HYPNOSIS_TRAP,
        type: :status,
        floors: 1..999,
        weight: 8,
        status: :SLEEP,
        graphic: "Dungeon Trap Hypnosis",
        message: "Nodding off? ",
        disappears: false
      },
      {
        id: :VOLTORB,
        type: :explosion,
        floors: 1..999,
        weight: 6,
        graphic: "Dungeon Trap Explosion",
        message: "BOOM!",
        disappears: true
      },
      {
        id: :SPIKE_FIELD,
        type: :spikes,
        floors: 1..999,
        weight: 8,
        graphic: "Dungeon Trap Spikes Down",
        message: "You stepped on spikes",
        disappears: false
      },
      {
        id: :PP_DRAIN,
        type: :PP_DOWN,
        floors: 1..999,
        weight: 4,
        graphic: "Dungeon Trap PP Down",
        message: "A strange portal opens beneath your feet!",
        disappears: true
      },
      {
        id: :PARALYZE_TRAP,
        type: :status,
        floors: 1..999,
        weight: 3,
        status: :PARALYSIS,
        graphic: "Dungeon Trap Paralysis",
        message: "Shock Trap! ",
        disappears: false
      },
      {
        id: :POISON_TRAP,
        type: :status,
        floors: 20..999,
        weight: 2,
        status: :POISON,
        graphic: "Dungeon Trap Poison Gas",
        message: "Catch !",
        disappears: false
      }
    ]
  end
end
