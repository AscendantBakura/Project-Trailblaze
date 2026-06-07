#-----------------------------------------------------------------------------
# Pickup updates
#-----------------------------------------------------------------------------
alias __roguelike__pbPickup pbPickup unless defined?(__roguelike__pbPickup)
def pbPickup(*args)
  pkmn = args[0]
  return if pkmn.egg? || !pkmn.hasAbility?(:PICKUP)
  return if pkmn.items_full?
  old_items = pkmn.items.clone
  pkmn.items.clear
  __roguelike__pbPickup(*args)
  new_item = pkmn.item_id
  old_items.each { |i| pkmn.add_item(i) }
  pkmn.add_item(new_item)
end

Battle::AbilityEffects::EndOfRoundGainItem.add(:PICKUP,
  proc { |ability, battler, battle|
    next if battler.items_full?
    found_item = nil
    from_battler = nil
    use = 0
    battle.allBattlers.each do |b|
      next if b.index == battler.index
      next if b.effects[PBEffects::PickupUse] <= use
      found_item   = b.effects[PBEffects::PickupItem]
      from_battler = b
      use          = b.effects[PBEffects::PickupUse]
    end
    next if !found_item
    battle.pbShowAbilitySplash(battler)
    battler.item = found_item
    from_battler.effects[PBEffects::PickupItem] = nil
    from_battler.effects[PBEffects::PickupUse]  = 0
    from_battler.setRecycleItem(nil) if from_battler.recycleItem == found_item
    if battle.wildBattle? && from_battler.has_initial_item?(found_item)
      battler.set_initial_item(found_item)
      from_battler.set_initial_item(nil, found_item)
    end
    battle.pbDisplay(_INTL("{1} found one {2}!", battler.pbThis, battler.itemName))
    battle.pbHideAbilitySplash(battler)
    battler.pbHeldItemTriggerCheck
  }
)

#-----------------------------------------------------------------------------
# Frisk
#-----------------------------------------------------------------------------
Battle::AbilityEffects::OnSwitchIn.add(:FRISK,
  proc { |ability, battler, battle, switch_in|
    next if !battler.pbOwnedByPlayer?
    foes = battle.allOtherSideBattlers(battler.index).reject(&:items_empty?)
    if !foes.empty?
      battle.pbShowAbilitySplash(battler)
      if Settings::MECHANICS_GENERATION >= 6
        foes.each do |b|
          battle.pbDisplay(_INTL("{1} frisked {2} and found its {3}!",
             battler.pbThis, b.pbThis(true), b.item_names_formatted))
        end
      else
        foe = foes[battle.pbRandom(foes.length)]
        battle.pbDisplay(_INTL("{1} frisked the foe and found one {2}!",
           battler.pbThis, foe.item_names_formatted))
      end
      battle.pbHideAbilitySplash(battler)
    end
  }
)

#-----------------------------------------------------------------------------
# Harvest changes
#-----------------------------------------------------------------------------
Battle::AbilityEffects::EndOfRoundGainItem.add(:HARVEST,
  proc { |ability, battler, battle|
    next if battler.items_full?
    next if !battler.recycleItem || !GameData::Item.get(battler.recycleItem).is_berry?
    next if ![:Sun, :HarshSun].include?(battler.effectiveWeather) && battle.pbRandom(100) >= 50
    battle.pbShowAbilitySplash(battler)
    battler.item = battler.recycleItem
    battler.setRecycleItem(nil)
    battler.setInitialItem(battler.item) if !battler.has_initial_item?(battler.item)
    battle.pbDisplay(_INTL("{1} harvested one {2}!", battler.pbThis, battler.itemName))
    battle.pbHideAbilitySplash(battler)
    battler.pbHeldItemTriggerCheck
  }
)

#-----------------------------------------------------------------------------
# Recycle changes
#-----------------------------------------------------------------------------
class Battle::Move::RestoreUserConsumedItem
  def pbMoveFailed?(user, targets)
    if !user.recycleItem || user.items_full?
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end

  def pbEffectGeneral(user)
    item = user.recycleItem
    user.item = item
    user.setInitialItem(item) if @battle.wildBattle? && !user.has_initial_item?(item)
    user.setRecycleItem(nil)
    user.effects[PBEffects::PickupItem] = nil
    user.effects[PBEffects::PickupUse]  = 0
    item_name = GameData::Item.get(item).name
    if item_name.starts_with_vowel?
      @battle.pbDisplay(_INTL("{1} found an {2}!", user.pbThis, item_name))
    else
      @battle.pbDisplay(_INTL("{1} found a {2}!", user.pbThis, item_name))
    end
    user.pbHeldItemTriggerCheck
  end
end

#-----------------------------------------------------------------------------
# Pickpocket changes
#-----------------------------------------------------------------------------
Battle::AbilityEffects::AfterMoveUseFromTarget.add(:PICKPOCKET,
  proc { |ability, target, user, move, switched_battlers, battle|
    next if target.wild?
    next if switched_battlers.include?(user.index)
    next if !move.contactMove?
    next if user.effects[PBEffects::Substitute] > 0 || target.damageState.substitute
    next if target.items_full? || user.losable_items.empty?
    item = user.losable_items.sample
    next if target.unlosableItem?(item)
    battle.pbShowAbilitySplash(target)
    if user.hasActiveAbility?(:STICKYHOLD)
      battle.pbShowAbilitySplash(user) if target.opposes?(user)
      if Battle::Scene::USE_ABILITY_SPLASH
        battle.pbDisplay(_INTL("{1}'s item cannot be stolen!", user.pbThis))
      end
      battle.pbHideAbilitySplash(user) if target.opposes?(user)
      battle.pbHideAbilitySplash(target)
      next
    end
    target.item = item
    user.remove_item(item)
    user.effects[PBEffects::Unburden] = true if user.hasActiveAbility?(:UNBURDEN)
    if battle.wildBattle? && !target.has_initial_item?(item) && user.has_initial_item?(item)
      target.setInitialItem(item)
      user.setInitialItem(nil, item)
    end
    battle.pbDisplay(_INTL("{1} pickpocketed {2}'s {3}!", target.pbThis,
       user.pbThis(true), target.itemName))
    battle.pbHideAbilitySplash(target)
    target.pbHeldItemTriggerCheck
  }
)

#-----------------------------------------------------------------------------
# Techno Blast, Judgement and RKS
#-----------------------------------------------------------------------------
class Battle::Move::TypeDependsOnUserDrive
  def pbBaseType(user)
    ret = :NORMAL
    @itemTypes.each do |item, type|
      next if !user.hasActiveItem?(item)
      ret = type if GameData::Type.exists?(type)
      break
    end
    return ret
  end
end

#-----------------------------------------------------------------------------
# Acrobatics changes
#-----------------------------------------------------------------------------
class Battle::Move::DoublePowerIfUserHasNoItem
  def pbBaseDamageMultiplier(damageMult, user, target)
    damageMult *= 2 if user.lost_item? || user.effects[PBEffects::GemConsumed] || user.items_empty?
    return damageMult
  end
end

#-----------------------------------------------------------------------------
# Bug Bite + Pluck Changes
#-----------------------------------------------------------------------------
class Battle::Move::UserConsumeTargetBerry
  def pbEffectAfterAllHits(user, target)
    return if user.fainted? || target.fainted?
    return if target.damageState.unaffected || target.damageState.substitute
    return if target.hasActiveAbility?(:STICKYHOLD) && !@battle.moldBreaker
    item = target.losable_items.select { |i| GameData::Item.get(i).is_berry? }.sample
    return if !item
    item_name = GameData::Item.get(item).name
    user.setBelched
    target.pbRemoveItem(item: item)
    @battle.pbDisplay(_INTL("{1} stole and ate its target's {2}!", user.pbThis, item_name))
    user.pbHeldItemTriggerCheck(item, false)
    user.pbSymbiosis
  end
end

#-----------------------------------------------------------------------------
# Incinerate changes
#-----------------------------------------------------------------------------
class Battle::Move::DestroyTargetBerryOrGem
  def pbEffectWhenDealingDamage(user, target)
    return if target.damageState.substitute || target.damageState.berryWeakened
    return if target.hasActiveAbility?(:STICKYHOLD) && !@battle.moldBreaker
    items = target.losable_items.select do |i|
      next true if GameData::Item.get(i).is_berry?
      next true if GameData::Item.get(i).is_gem? && Settings::MECHANICS_GENERATION >= 6
      next false
    end
    item = items.sample
    return if !item
    item_name = GameData::Item.get(item).name
    target.pbRemoveItem(item: item)
    @battle.pbDisplay(_INTL("{1}'s {2} was incinerated!", target.pbThis, item_name))
  end
end

#-----------------------------------------------------------------------------
# Covet, Thief changes
#-----------------------------------------------------------------------------
class Battle::Move::UserTakesTargetItem
  def pbEffectAfterAllHits(user, target)
    return if user.wild? || user.fainted?
    return if target.damageState.unaffected || target.damageState.substitute
    return if user.items_full?
    return if target.hasActiveAbility?(:STICKYHOLD) && !@battle.moldBreaker
    item = target.losable_items.sample
    return if !item || user.unlosableItem?(item)
    item_name = GameData::Item.get(item).name
    user.item = item
    if target.wild? && !user.has_initial_item?(item) && target.has_initial_item?(item)
      user.setInitialItem(item)
      target.pbRemoveItem(item: item)
    else
      target.pbRemoveItem(false, item: item)
    end
    @battle.pbDisplay(_INTL("{1} stole {2}'s {3}!", user.pbThis, target.pbThis(true), item_name))
    user.pbHeldItemTriggerCheck
  end
end

#-----------------------------------------------------------------------------
# Magician changes
#-----------------------------------------------------------------------------
Battle::AbilityEffects::OnEndOfUsingMove.add(:MAGICIAN,
  proc { |ability, user, targets, move, battle|
    next if battle.futureSight
    next if !move.pbDamagingMove?
    next if user.items_full?
    next if user.wild?
    targets.each do |b|
      next if b.damageState.unaffected || b.damageState.substitute
      item = b.losable_items.sample
      next if !item || user.unlosableItem?(item)
      battle.pbShowAbilitySplash(user)
      if b.hasActiveAbility?(:STICKYHOLD)
        battle.pbShowAbilitySplash(b) if user.opposes?(b)
        battle.pbDisplay(_INTL("{1}'s item cannot be stolen!", b.pbThis)) if Battle::Scene::USE_ABILITY_SPLASH
        battle.pbHideAbilitySplash(b) if user.opposes?(b)
        next
      end
      user.item = item
      b.remove_item(item)
      b.effects[PBEffects::Unburden] = true if b.hasActiveAbility?(:UNBURDEN)
      if battle.wildBattle? && !user.has_initial_item?(item) && b.has_initial_item?(item)
        user.setInitialItem(item)
        b.setInitialItem(nil, item)
      end
      if Battle::Scene::USE_ABILITY_SPLASH
        battle.pbDisplay(_INTL("{1} stole {2}'s {3}!", user.pbThis, b.pbThis(true), user.itemName))
      else
        battle.pbDisplay(_INTL("{1} stole {2}'s {3} with {4}!", user.pbThis, b.pbThis(true), user.itemName,
          user.abilityName))
      end
      battle.pbHideAbilitySplash(user)
      user.pbHeldItemTriggerCheck
      break
    end
  }
)

#-----------------------------------------------------------------------------
# Trick, Switcheroo changes
#-----------------------------------------------------------------------------
class Battle::Move::UserTargetSwapItems
  def pbOnStartUse(user, targets)
    super
    @user_item = user.losable_items.sample
    @target_items = {}
    targets.each { |target| @target_items[target] = target.losable_items.sample }
  end

  def pbFailsAgainstTarget?(user, target, show_message)
    if !@user_item && (!@target_items || !@target_items[target])
      @battle.pbDisplay(_INTL("But it failed!")) if show_message
      return true
    end
    target_item = @target_items[target]
    if target.unlosableItem?(target_item) ||
       target.unlosableItem?(@user_item) ||
       user.unlosableItem?(@user_item) ||
       user.unlosableItem?(target_item)
      @battle.pbDisplay(_INTL("But it failed!")) if show_message
      return true
    end
    if target.hasActiveAbility?(:STICKYHOLD) && !@battle.moldBreaker
      if show_message
        @battle.pbShowAbilitySplash(target)
        if Battle::Scene::USE_ABILITY_SPLASH
          @battle.pbDisplay(_INTL("But it failed to affect {1}!", target.pbThis(true)))
        else
          @battle.pbDisplay(_INTL("But it failed to affect {1} because of its {2}!",
                                  target.pbThis(true), target.abilityName))
        end
        @battle.pbHideAbilitySplash(target)
      end
      return true
    end
    return false
  end

  def pbEffectAgainstTarget(user, target)
    old_user_itm = @user_item
    user_itm_name = GameData::Item.get(@user_item).name
    old_target_itm = GameData::Item.get(@target_items[target]).name
    target_itm_name = target.itemName
    user.item                             = old_target_itm
    user.effects[PBEffects::ChoiceBand]   = nil if !user.hasActiveAbility?(:GORILLATACTICS)
    user.effects[PBEffects::Unburden]     = (!user.item && old_user_itm) if user.hasActiveAbility?(:UNBURDEN)
    target.item                           = old_user_itm
    target.effects[PBEffects::ChoiceBand] = nil if !target.hasActiveAbility?(:GORILLATACTICS)
    target.effects[PBEffects::Unburden]   = (!target.item && old_target_itm) if target.hasActiveAbility?(:UNBURDEN)
    if target.wild? && !user.has_initial_item?(old_target_itm) && target.has_initial_item(old_target_itm)
      user.setInitialItem(old_target_itm)
    end
    @battle.pbDisplay(_INTL("{1} switched items with its opponent!", user.pbThis))
    @battle.pbDisplay(_INTL("{1} obtained {2}.", user.pbThis, target_itm_name)) if old_target_itm
    @battle.pbDisplay(_INTL("{1} obtained {2}.", target.pbThis, user_itm_name)) if old_user_itm
    user.pbHeldItemTriggerCheck
    target.pbHeldItemTriggerCheck
  end
end

#-----------------------------------------------------------------------------
# Bestow changes
#-----------------------------------------------------------------------------
class Battle::Move::TargetTakesUserItem < Battle::Move
  def pbOnStartUse(user, targets)
    super
    @user_item = user.losable_items.sample
  end

  def pbMoveFailed?(user, targets)
    if !@user_item
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end

  def pbFailsAgainstTarget?(user, target, show_message)
    if target.losable_items.empty?
      @battle.pbDisplay(_INTL("But it failed!")) if show_message
      return true
    end
    return false
  end

  def pbEffectAgainstTarget(user, target)
    target.item = @user_item
    item_name = GameData::Item.get(@user_item).name
    if user.wild? && !target.has_initial_item?(@user_item) && user.has_initial_item?(@user_item)
      target.setInitialItem(@user_item)
      user.pbRemoveItem(item: @user_item)
    else
      user.pbRemoveItem(false, item: @user_item)
    end
    @battle.pbDisplay(_INTL("{1} received {2} from {3}!", target.pbThis, item_name, user.pbThis(true)))
    target.pbHeldItemTriggerCheck
  end
end

#-----------------------------------------------------------------------------
# Knock off changes
#-----------------------------------------------------------------------------
class Battle::Move::RemoveTargetItem < Battle::Move
  def pbOnStartUse(user, targets)
    super
    @target_item = {}
    targets.each { |target| @target_item[target] = target.losable_items.sample }
  end

  def pbBaseDamage(baseDmg, user, target)
    target_item = (@target_item) ? @target_item[target] : nil
    baseDmg = (baseDmg * 1.5).round if Settings::MECHANICS_GENERATION >= 6 && target_item
    return baseDmg
  end

  def pbEffectAfterAllHits(user, target)
    return if user.wild?
    return if user.fainted?
    return if target.damageState.unaffected || target.damageState.substitute
    return if target.hasActiveAbility?(:STICKYHOLD) && !@battle.moldBreaker
    target_item = (@target_item) ? @target_item[target] : nil
    return if !target_item
    item_name = GameData::Item.get(target_item).name
    target.pbRemoveItem(false, item: target_item)
    @battle.pbDisplay(_INTL("{1} dropped its {2}!", target.pbThis, item_name))
  end
end

#-----------------------------------------------------------------------------
# Natural Gift changes
#-----------------------------------------------------------------------------
class Battle::Move::TypeAndPowerDependOnUserBerry < Battle::Move
  def pbOnStartUse(user, targets)
    super
    user_items = user.losable_items.select do |item|
      next false if !GameData::Item.get(item).is_berry?
      next false if GameData::Item.get(item).flags.none? { |f| f[/^NaturalGift_/i] }
      next true
    end
    @user_item = user_items.sample
  end

  def pbMoveFailed?(user, targets)
    if !user.itemActive? || !@user_item || GameData::Item.get(@user_item).flags.none? { |f| f[/^NaturalGift_/i] }
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end

  def pbBaseType(user)
    ret = :NORMAL
    item = @user_item
    return ret if !item
    item.flags.each do |flag|
      next if !flag[/^NaturalGift_(\w+)_(?:\d+)$/i]
      typ = $~[1].to_sym
      ret = typ if GameData::Type.exists?(typ)
      break
    end
    return ret
  end

  def pbBaseDamage(baseDmg, user, target)
    item_id = @user_item
    return 1 if !item_id
    GameData::Item.get(item_id).flags.each do |flag|
      return [$~[1].to_i, 10].max if flag[/^NaturalGift_(?:\w+)_(\d+)$/i]
    end
    return 1
  end

  def pbEndOfMoveUsageEffect(user, targets, numHits, switchedBattlers)
    user.pbConsumeItem(true, true, false, item: @user_item) if @user_item
  end
end


#-----------------------------------------------------------------------------
# Fling changes
#-----------------------------------------------------------------------------
class Battle::Move::ThrowUserItemAtTarget
  def pbOnStartUse(user, targets)
    super
    @user_item = user.losable_items.sample
  end

  def pbCheckFlingSuccess(user)
    @willFail = false
    @willFail = true if !user.itemActive? || !@user_item
    return if @willFail
    item_data = GameData::Item.get(@user_item)
    @willFail = true if item_data.is_berry? && !user.canConsumeBerry?
    return if @willFail
    @willFail = item_data.flags.none? { |f| f[/^Fling_/i] }
  end

  def pbDisplayUseMessage(user)
    super
    pbCheckFlingSuccess(user)
    if !@willFail
      @battle.pbDisplay(_INTL("{1} flung its {2}!", user.pbThis, GameData::Item.get(@user_item).name))
    end
  end

  def pbBaseDamage(baseDmg, user, target)
    return 0 if !@user_item
    item_data = GameData::Item.get(@user_item)
    item_data.flags.each do |flag|
      return [$~[1].to_i, 10].max if flag[/^Fling_(\d+)$/i]
    end
    return 10
  end

  def pbEffectAgainstTarget(user, target)
    return if target.damageState.substitute
    return if target.hasActiveAbility?(:SHIELDDUST) && !@battle.moldBreaker
    case @user_item
    when :POISONBARB
      target.pbPoison(user) if target.pbCanPoison?(user, false, self)
    when :TOXICORB
      target.pbPoison(user, nil, true) if target.pbCanPoison?(user, false, self)
    when :FLAMEORB
      target.pbBurn(user) if target.pbCanBurn?(user, false, self)
    when :LIGHTBALL
      target.pbParalyze(user) if target.pbCanParalyze?(user, false, self)
    when :KINGSROCK, :RAZORFANG
      target.pbFlinch(user)
    else
      target.pbHeldItemTriggerCheck(@user_item, true)
    end
    target.setBelched if GameData::Item.get(@user_item).is_berry?
  end

  def pbEndOfMoveUsageEffect(user, targets, numHits, switchedBattlers)
    user.pbConsumeItem(true, true, false, item: @user_item) if @user_item
  end
end

#-----------------------------------------------------------------------------
# Sticky Barb changes
#-----------------------------------------------------------------------------
Battle::ItemEffects::OnBeingHit.add(:STICKYBARB,
  proc { |item, user, target, move, battle|
    next if !move.pbContactMove?(user) || !user.affectedByContactEffect?
    next if user.fainted? || user.items_full?
    user.item = :STICKYBARB
    target.remove_item(:STICKYBARB)
    target.effects[PBEffects::Unburden] = true if target.hasActiveAbility?(:UNBURDEN)
    if battle.wildBattle? && !user.opposes? &&
       !user.has_initial_item?(:STICKYBARB) && target.has_initial_item?(:STICKYBARB)
      user.setInitialItem(:STICKYBARB)
      target.setInitialItem(nil, :STICKYBARB)
    end
    battle.pbDisplay(_INTL("{1}'s {2} was transferred to {3}!",
       target.pbThis, user.itemName, user.pbThis(true)))
  }
)

#-----------------------------------------------------------------------------
# Stuff Cheeks changes
#-----------------------------------------------------------------------------
class Battle::Move::UserConsumeBerryRaiseDefense2
  def pbCanChooseMove?(user, commandPhase, showMessages)
    user_items = user.losable_items.select { |item| GameData::Item.get(item).is_berry? }
    @user_item = user_items.sample
    item = @user_item
    if !item || !GameData::Item.get(item).is_berry? || !user.itemActive?
      if showMessages
        msg = _INTL("{1} can't use that move because it doesn't have a Berry!", user.pbThis)
        (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
      end
      return false
    end
    return true
  end

  def pbMoveFailed?(user, targets)
    item = @user_item
    if !item || !GameData::Item.get(item).is_berry? || !user.itemActive?
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return super
  end

  def pbEffectGeneral(user)
    super
    item = @user_item
    @battle.pbDisplay(_INTL("{1} ate its {2}!", user.pbThis, GameData::Item.get(item).name))
    user.pbConsumeItem(true, false, item: item)
    user.pbHeldItemTriggerCheck(item, false)
  end
end

#-----------------------------------------------------------------------------
# Tea Time changes
#-----------------------------------------------------------------------------
class Battle::Move::AllBattlersConsumeBerry < Battle::Move
  def pbMoveFailed?(user, targets)
    failed = true
    targets.each do |b|
      berries = b.losable_items.select { |item| GameData::Item.get(item).is_berry? }
      next if !berries || berries.empty?
      next if b.semiInvulnerable?
      failed = false
      break
    end
    if failed
      @battle.pbDisplay(_INTL("But nothing happened!"))
      return true
    end
    return false
  end

  def pbFailsAgainstTarget?(user, target, show_message)
    berries = target.losable_items.select { |item| GameData::Item.get(item).is_berry? }
    return true if !berries || berries.empty? || target.semiInvulnerable?
    return false
  end

  def pbEffectAgainstTarget(user, target)
    @battle.pbCommonAnimation("EatBerry", target)
    berries = target.losable_items.select { |item| GameData::Item.get(item).is_berry? }
    item = berries.sample
    target.pbConsumeItem(true, false, item: item)
    target.pbHeldItemTriggerCheck(item, false)
  end
end

#-----------------------------------------------------------------------------
# Booster Energy changes
#-----------------------------------------------------------------------------
Battle::AbilityEffects::OnSwitchIn.add(:PROTOSYNTHESIS,
  proc { |ability, battler, battle, switch_in|
    next if battler.effects[PBEffects::Transform]
    case ability
    when :PROTOSYNTHESIS then field_check = [:Sun, :HarshSun].include?(battle.pbWeather)
    when :QUARKDRIVE     then field_check = battle.field.terrain == :Electric
    end
    if !field_check && !battler.effects[PBEffects::BoosterEnergy] && battler.effects[PBEffects::ParadoxStat]
      battle.pbDisplay(_INTL("The effects of {1}'s {2} wore off!", battler.pbThis(true), battler.abilityName))
      battler.effects[PBEffects::ParadoxStat] = nil
    end
    next if battler.effects[PBEffects::ParadoxStat]
    next if !field_check && !battler.items.include?(:BOOSTERENERGY)
    highestStat = nil
    highestStatVal = 0
    stageMul = [2, 2, 2, 2, 2, 2, 2, 3, 4, 5, 6, 7, 8]
    stageDiv = [8, 7, 6, 5, 4, 3, 2, 2, 2, 2, 2, 2, 2]
    battler.plainStats.each do |stat, val|
      stage = battler.stages[stat] + 6
      realStat = (val.to_f * stageMul[stage] / stageDiv[stage]).floor
      if realStat > highestStatVal
        highestStatVal = realStat
        highestStat = stat
      end
    end
    if highestStat
      battle.pbShowAbilitySplash(battler)
      if field_check
        case ability
        when :PROTOSYNTHESIS then cause = "harsh sunlight"
        when :QUARKDRIVE     then cause = "Electric Terrain"
        end
        battle.pbDisplay(_INTL("The #{cause} activated {1}'s {2}!", battler.pbThis(true), battler.abilityName))
      elsif battler.items.include?(:BOOSTERENERGY)
        item_name = GameData::Item.get(:BOOSTERENERGY).name
        battler.effects[PBEffects::BoosterEnergy] = true
        battle.pbDisplay(_INTL("{1} used its {2} to activate its {3}!", battler.pbThis, item_name, battler.abilityName))
        battler.pbHeldItemTriggered(:BOOSTERENERGY)
      end
      battler.effects[PBEffects::ParadoxStat] = highestStat
      battle.pbDisplay(_INTL("{1}'s {2} was heightened!", battler.pbThis, GameData::Stat.get(highestStat).name))
      battle.pbHideAbilitySplash(battler)
    end
  }
)

Battle::AbilityEffects::OnSwitchIn.copy(:PROTOSYNTHESIS, :QUARKDRIVE)

#-----------------------------------------------------------------------------
# Cud Chew changes
#-----------------------------------------------------------------------------
Battle::AbilityEffects::EndOfRoundEffect.add(:CUDCHEW,
  proc { |ability, battler, battle|
    next if !battler.lost_item?
    next if !battler.recycleItem || !GameData::Item.get(battler.recycleItem).is_berry?
    case battler.effects[PBEffects::CudChew]
    when 0
      battler.effects[PBEffects::CudChew] += 1
    else
      battler.effects[PBEffects::CudChew] = 0
      battle.pbShowAbilitySplash(battler, true)
      battle.pbHideAbilitySplash(battler)
      battler.pbHeldItemTriggerCheck(battler.recycleItem, true)
      battler.setRecycleItem(nil)
    end
  }
)
