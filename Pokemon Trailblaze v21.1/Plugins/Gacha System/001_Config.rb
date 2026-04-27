#===============================================================================
# * Gacha System Configuration
#===============================================================================

module GachaConfig
  # Default item used for paying the gacha (if not specified in the banner)
  DEFAULT_COST_ITEM = :GACHATICKET 
  
  # Ensure the item exists in the PBS. If it doesn't, we will fall back to Money if configured.
  
  BANNERS = {
    # --------------------------------------------------------------------------
    # Example 1: Pokemon Banner
    # This banner only gives Pokemon.
    # --------------------------------------------------------------------------
    :RESHIRAM_BANNER => {
      name: "Destiny Banner",
      cost_item: :GACHATICKET, # Item used to roll
      cost_amount: 1,          # How many items it costs
      banner_image: "Graphics/UI/Gacha/empty_banner", # Background/Main image for this banner
      bgm: "Evolution", # Background music while rolling (optional)
      anim_closed: "Graphics/UI/Gacha/pokeball_closed", # Graphic before opening
      anim_style: :shake, # Animation type: :shake or :jump
      pity_limit: 90, # 100% chance for a main prize on the 90th roll
      soft_pity_start: 70, # Increased chance for main prize starting at the 70th roll
      soft_pity_increase: 50, # How much weight to add per roll past the soft pity target
      
      pools: [
        # { type: :pokemon, species: :SPECIES, level: LEVEL, probability: WEIGHT, shiny_chance: PERCENT, nature: :NATURE, ability: :ABILITY, ability_index: INDEX }
        { type: :pokemon, species: :RESHIRAM, level: 50, probability: 90, is_main_prize: true, shiny_chance: 10, nature: :MODEST, ability: :TURBOBLAZE},
        { type: :pokemon, species: :ZEKROM, level: 50, probability: 1, nature: :LONELY, ability: :TERAVOLT },
        { type: :pokemon, species: :DRAGONITE, level: 40, probability: 10 },
        { type: :pokemon, species: :CHARIZARD, level: 36, probability: 10 },
        { type: :pokemon, species: :PIDGEOT, level: 30, probability: 40 },
        { type: :pokemon, species: :RATTATA, level: 5, probability: 60 }
      ]
    },
    
    # --------------------------------------------------------------------------
    # Example 2: Item Banner
    # This banner only gives items.
    # --------------------------------------------------------------------------
    :ITEM_PREMIUM_BANNER => {
      name: "Premium Items",
      cost_item: :GACHATICKET,
      cost_amount: 1,
      banner_image: "Graphics/UI/Gacha/item_banner_v2",
      anim_closed: "Graphics/UI/Gacha/itembox_closed",
      anim_style: :jump,
      pity_limit: 50,
      soft_pity_start: 40,
      soft_pity_increase: 20,
      
      pools: [
        # { type: :item, item: :ITEM_ID, amount: AMOUNT, probability: WEIGHT }
        { type: :item, item: :MASTERBALL, amount: 1, probability: 1 ,is_main_prize: true },
        { type: :item, item: :RARECANDY, amount: 5, probability: 10 },
        { type: :item, item: :ULTRABALL, amount: 10, probability: 30 },
        { type: :item, item: :POTION, amount: 5, probability: 70 }
      ]
    }
  }
end
