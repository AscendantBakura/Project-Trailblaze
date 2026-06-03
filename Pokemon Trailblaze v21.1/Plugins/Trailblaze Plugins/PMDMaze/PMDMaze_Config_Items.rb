module PMDDungeon
  module ItemConfig
    # Example:
    # DEFAULT_ITEM_EVENT_COUNT = (1..3)
    DEFAULT_ITEM_EVENT_COUNT = 0

    # Example:
    # ITEM_EVENT_COUNT_BY_FLOOR = {
    #   1 => (1..2),
    #   2 => (2..3)
    # }
    ITEM_EVENT_COUNT_BY_FLOOR = {}

    # Example:
    # FORCED_ITEMS_BY_FLOOR = {
    #   3 => [:POTION]
    # }
    FORCED_ITEMS_BY_FLOOR = {}

    # Example chest graphics by rarity.
    ITEM_RARITY_GRAPHIC = {
      common:   { graphic: "Dungeon Chest Common",   open_direction: 8, open_pattern: 0 },
      uncommon: { graphic: "Dungeon Chest Uncommon", open_direction: 8, open_pattern: 0 },
      rare:     { graphic: "Dungeon Chest Rare",     open_direction: 8, open_pattern: 0 },
      sr:       { graphic: "Dungeon Chest SR",       open_direction: 8, open_pattern: 0 }
    }

    # Item pool for random dungeon chests.
    # Keys:
    #   :item          => item symbol
    #   :floors        => Integer, Range, Array, or nil for any floor
    #   :weight        => spawn weight (higher = more common)
    #   :rarity        => :common, :uncommon, :rare, :sr (determines chest graphic)
    #   :unique_run    => if true, only one per full run
    #   :max_total     => hard cap across entire run
    #   :max_per_floor => hard cap per floor
    #   :min_floor_gap => min floors before item appears again
    ITEM_POOL = [
      { item: :POTION, floors: 1..999, weight: 20, rarity: :common },
      { item: :ANTIDOTE, floors: 1..999, weight: 8, rarity: :common },
      { item: :AWAKENING, floors: 1..999, weight: 8, rarity: :common },
      { item: :PARALYZEHEAL, floors: 1..999, weight: 8, rarity: :common },
      { item: :SUPERPOTION, floors: 5..999, weight: 12, rarity: :uncommon },
      { item: :SITRUSBERRY, floors: 1..999, weight: 10, rarity: :uncommon },
      { item: :POKEBALL, floors: 1..999, weight: 15, rarity: :common },
      { item: :GREATBALL, floors: 1..999, weight: 8, rarity: :uncommon },
      { item: :REVIVE, floors: 1..999, weight: 3, rarity: :rare },
      { item: :FULLRESTORE, floors: 1..999, weight: 2, rarity: :sr, unique_run: true }
    ]
  end
end