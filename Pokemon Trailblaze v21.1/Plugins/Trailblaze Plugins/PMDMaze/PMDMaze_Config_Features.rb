#===============================================================================
# PMDMaze - Dungeon feature configuration (Trailblaze restoration)
#===============================================================================
module PMDDungeon
  module FeatureConfig
    #--------------------------------------------------------------------------
    # F.O.E. - one powerful Pokémon per run. It starts at the bottom floor
    # (FloorLimit) or FOE_START_DEPTH floors below the entry floor, slowly
    # climbs toward the player and, once beaten, is gone for the rest of the run.
    #--------------------------------------------------------------------------
    FOE_ENABLED       = true
    FOE_START_DEPTH   = 10           # floors below the entry (unlimited dungeons)
    FOE_CLIMB_STEPS   = 300          # player steps per floor the F.O.E. moves
    FOE_GRAPHIC       = "auto"       # "auto" = Followers/<species>
    FOE_MOVE_SPEED    = 4
    # F.O.E. and hunter fights are raid battles ([DBK] Raid Battles plugin,
    # RaidBattle.start). The F.O.E. is always the stronger raid: higher rank
    # and level, thicker shield, more boss actions, and fewer turns/KOs for
    # the player. Species must be raid species (PBS RaidRanks) for :style.
    # Pokemon cannot be captured and the player cannot run.
    FOE_RAID = {
      species:       [:GENGAR],
      style:         :Basic,
      rank:          4,
      level_bonus:   8,              # added to the normal floor wild level
      turn_count:    8,
      ko_count:      3,
      shield_hp:     6,
      extra_actions: [:reset_drops, :reset_boosts]
    }

    #--------------------------------------------------------------------------
    # Dungeon trainers (named "Trainer(n)" so the engine's sight check works).
    # Every type here has an animated front strip (Graphics/Trainers) and an
    # overworld charset; trainers are never placed on grass/hiding tiles.
    #--------------------------------------------------------------------------
    TRAINER_CHANCE     = 0.45
    TRAINER_MIN_FLOOR  = 1
    TRAINER_SIGHT      = 4
    TRAINERS = [
      { type: :HIKER,     graphic: "trainer_HIKER",     names: ["Marcos", "Russell", "Anthony"] },
      { type: :BLACKBELT, graphic: "trainer_BLACKBELT", names: ["Kenji", "Ricky", "Nob"] },
      { type: :BEAUTY,    graphic: "trainer_BEAUTY",    names: ["Bridget", "Olivia", "Lola"] },
      { type: :PSYCHIC_M, graphic: "trainer_PSYCHIC_M", names: ["Fidel", "Jaylen", "Rodette"] },
      { type: :PSYCHIC_F, graphic: "trainer_PSYCHIC_F", names: ["Alexis", "Rachel", "Mariah"] }
    ]
    TRAINER_SPECIES = [:PIDGEY, :RATTATA, :SENTRET, :HOOTHOOT, :ZIGZAGOON, :LILLIPUP,
                       :PATRAT, :BIDOOF, :STARLY, :WURMPLE, :CATERPIE, :WEEDLE]
    TRAINER_MONEY_BASE = 40

    #--------------------------------------------------------------------------
    # Hunter - a mini-boss Pokémon that appears after spending HUNTER_SECONDS
    # on the current floor (the clock restarts on every new floor).
    #--------------------------------------------------------------------------
    HUNTER_ENABLED     = true
    HUNTER_MIN_FLOOR   = 2
    HUNTER_SECONDS     = 180
    HUNTER_GRAPHIC     = "auto"       # "auto" = Followers/<species>
    HUNTER_NAME        = "Hunter"     # title shown in messages
    HUNTER_RAID = {
      species:       [:MIGHTYENA, :HOUNDOOM, :SNEASEL],
      style:         :Basic,
      rank:          2,
      level_bonus:   3,
      turn_count:    12,
      ko_count:      5,
      shield_hp:     3,
      extra_actions: []
    }
    HUNTER_MOVE_SPEED  = 4

    #--------------------------------------------------------------------------
    # Smuggler - sells items at high prices; stock persists for the whole run.
    # The shop scene uses the layered art in SMUGGLER_SHOP_ART (background,
    # shopkeeper, Eyes/<expr>_eyes, Mouths/<expr>_mouth) with blinking, talking
    # and expressions. Missing layers are reported, never silently replaced.
    #--------------------------------------------------------------------------
    SMUGGLER_CHANCE      = 0.25
    SMUGGLER_MIN_FLOOR   = 2
    SMUGGLER_GRAPHIC     = "NPC Unova Punk"
    SMUGGLER_PRICE_MULT  = 2.5
    SMUGGLER_STOCK_SIZE  = 4
    SMUGGLER_STOCK = [
      [:POTION, 3], [:SUPERPOTION, 2], [:ANTIDOTE, 2], [:PARALYZEHEAL, 2],
      [:AWAKENING, 2], [:ESCAPEROPE, 1], [:POKEBALL, 5], [:GREATBALL, 2],
      [:REVIVE, 1], [:ETHER, 1]
    ]
    SMUGGLER_SHOP_ART = "Graphics/UI/overlayUI/Shop Sprite"

    #--------------------------------------------------------------------------
    # Item restriction on entering a dungeon.
    #   :none      - bag untouched (default)
    #   :store_all - every non-key item is stored at the entrance and given
    #                back when the run ends (exit, defeat or milestone)
    #--------------------------------------------------------------------------
    ITEM_RESTRICTION = :none
    ITEM_RESTRICTION_ALLOWED = []

    #--------------------------------------------------------------------------
    # Defeat inside a dungeon run.
    #--------------------------------------------------------------------------
    DEFEAT_MONEY_FRACTION = 0.5
    DEFEAT_DESTINATION    = [102, 17, 10, 6]   # player's house, next to Mom

    #--------------------------------------------------------------------------
    # Bank (deposits are safe from the defeat penalty).
    #--------------------------------------------------------------------------
    BANK_VARIABLE = 149

    #--------------------------------------------------------------------------
    # Bounty board quests.
    #   kind :defeat - a wanted trainer appears on a floor in range
    #   kind :find   - a lost item appears on a floor in range
    #--------------------------------------------------------------------------
    BOUNTIES = [
      { id: :LOST_SATCHEL, kind: :find, name: "Lost Satchel",
        description: "A hiker dropped a satchel in Beginner Park.",
        floors: 2..4, graphic: "Dungeon Chest Common", reward_money: 600, reward_item: :SUPERPOTION },
      { id: :PARK_BULLY, kind: :defeat, name: "Park Bully",
        description: "Someone is picking fights deep in Beginner Park.",
        floors: 3..6, graphic: "NPC Outlaw", trainer_type: :HOOLIGANS, trainer_name: "Bully",
        reward_money: 1200, reward_item: :GREATBALL }
    ]
    # :defeat bounty targets wait in the centre of a room with one entrance and
    # no traps. Extra entrances are sealed with this graphic when sealing keeps
    # every other room and both stairs reachable; otherwise another room/floor
    # is used.
    BOUNTY_SEAL_EXTRA_ENTRANCES = true
    BOUNTY_SEAL_GRAPHIC         = "Object boulder"

    #--------------------------------------------------------------------------
    # Fleeing criminals - no battle. They run from the player; talking to one
    # offers a bribe item. Accept: item + Chaos aura, the criminal keeps
    # roaming. Refuse: Law aura and the criminal is arrested (removed).
    #--------------------------------------------------------------------------
    CRIMINAL_CHANCE    = 0.3
    CRIMINAL_MIN_FLOOR = 1
    CRIMINALS = [
      { name: "Pickpocket", graphic: "HGSS Burglar (Overworld)", portrait: :HOOLIGANS },
      { name: "Smuggler's Runner", graphic: "NPC Unova Punk", portrait: :BIKER }
    ]
    CRIMINAL_BRIBES   = [:NUGGET, :PEARL, :STARDUST, :BIGPEARL, :RARECANDY]
    LAW_VARIABLE      = 19
    CHAOS_VARIABLE    = 20
    AURA_STEP         = 1

    #--------------------------------------------------------------------------
    # Recruitable ally. Recruited from a town event (not the dungeon entrance);
    # follows across maps (native Followers) and fights beside the player in
    # double battles (native partner trainer, own party and back sprite).
    #--------------------------------------------------------------------------
    ALLY_FOLLOWER_NAME = "PMDAlly"
    ALLIES = {
      HILDA: { name: "Hilda", trainer_type: :POKEMONTRAINER_Hilda, charset: "NPC Hilda",
               party: [:TEPIG, :PURRLOIN], min_level: 5, level_offset: 0 }
    }

    #--------------------------------------------------------------------------
    # Grass (floor_patch) generation: patch chance is multiplied by this.
    #--------------------------------------------------------------------------
    GRASS_PATCH_FACTOR = 0.35

    #--------------------------------------------------------------------------
    # Debug: adds "PMD dungeon tools" to the debug menu; pbPMDDungeonDebug opens
    # the same tools from an event.
    #--------------------------------------------------------------------------
    DEBUG_MENU = true

    #--------------------------------------------------------------------------
    # Stealth: standing on these tiles hides the player in a dungeon.
    # Hidden players are ignored by trainers, F.O.E./hunter chasers and
    # overworld wild Pokémon (no spawns, no chasing).
    #--------------------------------------------------------------------------
    HIDING_TILE_RANGES = { 44 => [48..95], 7 => [48..95] }   # floor_patch autotile
    HIDING_TERRAIN_TAGS = [2]                                  # tall grass
    HIDDEN_OPACITY = 128

    #--------------------------------------------------------------------------
    # Random event / treasure rooms.
    #--------------------------------------------------------------------------
    TREASURE_ROOM_CHANCE = 0.3
    TREASURE_CHESTS = [
      { graphic: "Dungeon Chest Common",   weight: 60, loot: [:POTION, :ANTIDOTE, :POKEBALL, :ORANBERRY] },
      { graphic: "Dungeon Chest Uncommon", weight: 25, loot: [:SUPERPOTION, :GREATBALL, :ETHER] },
      { graphic: "Dungeon Chest Rare",     weight: 12, loot: [:HYPERPOTION, :ULTRABALL, :REVIVE] },
      { graphic: "Dungeon Chest SR",       weight: 3,  loot: [:MAXREVIVE, :RARECANDY, :PPUP] }
    ]
  end
end
