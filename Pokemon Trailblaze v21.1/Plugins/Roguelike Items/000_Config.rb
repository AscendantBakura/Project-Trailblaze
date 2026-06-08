class RewardItemUI
  # The Switch ID of the switch which needs to be ON to enable
  # the reward screen at the end of a battle. Setting this to -1
  # shows the rewards for all battles.
  REWARD_SCREEN_ENABLE_SWITCH = 125

  # The Variable ID of the variable which controls the number
  # of rewards seen in the reward screen. If the value of this
  # variable is less than 5, the number of rewards shown is 5.
  REWARD_COUNT_VARIABLE       = 99

  # The Variable ID of the variable which controls the reroll
  # cost in the rewards screen. If the value of this
  # variable is less than 1, the reroll cost is 1.
  REWARD_REROLL_COST_VARIABLE = 98

  # Whether the player can close the Reward UI without selecting
  # a reward (true) or not (false).
  CAN_CANCEL_REWARD_SCREEN    = true
end

class GameData::RewardPool
  # The different rarities and the chances for them to appear
  RARITY_DATA = {
    :common    => {
      :name   => _INTL("Common"),
      :chance => 50,
      :color  => Color.new(208, 208, 216)
    },
    :rare      => {
      :name   => _INTL("Rare"),
      :chance => 30,
      :color  => Color.new(120, 184, 232)
    },
    :epic      => {
      :name   => _INTL("Epic"),
      :chance => 15,
      :color  => Color.new(184, 168, 224)
    },
    :legendary => {
      :name   => _INTL("Legendary"),
      :chance => 5,
      :color  => Color.new(248, 200, 152)
    }
  }

  # Defines the fallback order when a chosen rarity pool is empty (highest to lowest).
  RARITY_FALLBACK_ORDER = [:legendary, :epic, :rare, :common]

  # The item ID for the Lucky Charm ie the item which boosts the chance of
  # getting rarer items in your rewards more often.
  LUCKY_CHARM_ITEM_ID         = :LUCKYCHARM

  # The total percentage points to shift from lower rarities to higher ones
  # when the Lucky Charm item is present. A value of 15 means that 15%
  # is taken from the lowest tiers and given to the highest tiers.
  LUCKY_CHARM_STRENGTH        = 15
end
