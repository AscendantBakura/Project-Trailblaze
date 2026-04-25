#===============================================================================
# Item handlers.
#===============================================================================
module ItemHandlers
  CanUseWithLauncher = ItemHandlerHash.new
  
  #-----------------------------------------------------------------------------
  # Edited to check items for Wonder Launcher eligibility.
  #-----------------------------------------------------------------------------
  def self.triggerCanUseInBattle(item, pkmn, battler, move, firstAction, battle, scene, showMessages = true, idxBattler = nil)
    if battle.launcherBattle?
      return false if !CanUseWithLauncher.trigger(item, battle, (idxBattler || battler), scene, showMessages)
    end
    return true if !CanUseInBattle[item]
    return CanUseInBattle.trigger(item, pkmn, battler, move, firstAction, battle, scene, showMessages)
  end
end

#-------------------------------------------------------------------------------
# General handler for all items usable with the Wonder Launcher.
#-------------------------------------------------------------------------------
# Ensures the trainer has enough Wonder Launcher points to use the item.
#-------------------------------------------------------------------------------
ItemHandlers::CanUseWithLauncher.addIf(:wonder_launcher,
  proc { |item| GameData::Item.get(item).is_launcher_item? },
  proc { |item, battle, idxBattler, scene, showMessages|
    battle = battle.battle if battle.is_a?(Battle::AI)
    next false if !battle.launcherBattle?
    idxBattler = idxBattler.index if idxBattler.respond_to?("index")
    side = (battle.opposes?(idxBattler)) ? 1 : 0
    index = battle.pbGetOwnerIndexFromBattlerIndex(idxBattler)
    points = GameData::Item.get(item).launcher_points
    if points <= 0 || points > battle.launcherPoints[side][index]
      scene.pbDisplay(_INTL("Not enough Launcher Points.")) if showMessages
      next false
    end
    next true
  }
)

#-------------------------------------------------------------------------------
# General handler for all Battle items that can target a battler.
#-------------------------------------------------------------------------------
# Prevents usage if the target battler is under the effects of Embargo.
#-------------------------------------------------------------------------------
ItemHandlers::CanUseInBattle.add(:RESETURGE, proc { |item, pokemon, battler, move, firstAction, battle, scene, showMessages|
  if battler && battler.effects[PBEffects::Embargo] > 0
    scene.pbDisplay(_INTL("Embargo's effect prevents the item's use on {1}!", battler.pbThis(true))) if showMessages
    next false
  end
  next true
})

ItemHandlers::CanUseInBattle.copy(:RESETURGE, :ITEMDROP, :ITEMURGE, :ABILITYURGE)

#-------------------------------------------------------------------------------
# Reset Urge
#-------------------------------------------------------------------------------
# Resets a target battler's stat changes, including critical hit increases.
#-------------------------------------------------------------------------------
ItemHandlers::UseInBattle.add(:RESETURGE, proc { |item, battler, battle|
  if battler.hasAlteredStatStages? || battler.effects[PBEffects::FocusEnergy] > 0
    battler.pbResetStatStages
    battler.effects[PBEffects::FocusEnergy] = 0
    battle.pbDisplayBrief(_INTL("{1}'s stat changes returned to normal!", battler.pbThis))
  else
    battle.pbDisplay(_INTL("But it failed!"))
  end
})

#-------------------------------------------------------------------------------
# Item Drop
#-------------------------------------------------------------------------------
# Forces the target battler to drop its held item, if possible.
#-------------------------------------------------------------------------------
ItemHandlers::UseInBattle.add(:ITEMDROP, proc { |item, battler, battle|
  if battler.item && !battler.hasActiveAbility?(:STICKYHOLD) && !battler.unlosableItem?(battler.item)
    itemName = battler.itemName
    battler.pbRemoveItem(false)
    battle.pbDisplayBrief(_INTL("{1} was forced to drop its held {2}!", battler.pbThis, itemName))
  else
    battle.pbDisplay(_INTL("But it failed!"))
  end
})

#-------------------------------------------------------------------------------
# Item Urge
#-------------------------------------------------------------------------------
# Forces the target battler to consume its held item prematurely, if possible.
#-------------------------------------------------------------------------------
ItemHandlers::UseInBattle.add(:ITEMURGE, proc { |item, battler, battle|
  usableItem = false
  if battler.item && battler.itemActive?
    stats = []
    GameData::Stat.each_battle { |s| stats.push(s.id) }
    item_id = battler.item_id
    case item_id
    #---------------------------------------------------------------------------
    # Status cure items
    when :RAWSTBERRY  then usableItem = battler.status == :BURN
    when :PECHABERRY  then usableItem = battler.status == :POISON
    when :CHERIBERRY  then usableItem = battler.status == :PARALYSIS
    when :CHESTOBERRY then usableItem = [:SLEEP, :DROWSY].include?(battler.status)
    when :ASPEARBERRY then usableItem = [:FROZEN, :FROSTBITE].include?(battler.status)
    when :PERSIMBERRY then usableItem = battler.effects[PBEffects::Confusion] > 0
    when :LUMBERRY    then usableItem = battler.status != :NONE || battler.effects[PBEffects::Confusion] > 0
    #---------------------------------------------------------------------------
    # Stat changing items
    when :LIECHIBERRY then usableItem = battler.pbCanRaiseStatStage?(:ATTACK, battler)
    when :PETAYABERRY then usableItem = battler.pbCanRaiseStatStage?(:SPECIAL_ATTACK, battler)
    when :SALACBERRY  then usableItem = battler.pbCanRaiseStatStage?(:SPEED, battler)
    when :STARFBERRY  then usableItem = stats.any? { |s| battler.pbCanRaiseStatStage?(s, battler) }
    when :MICLEBERRY  then usableItem = !battler.effects[PBEffects::MicleBerry]
    when :LANSATBERRY then usableItem = battler.effects[PBEffects::FocusEnergy] < 2
    when :WHITEHERB   then usableItem = stats.any? { |s| battler.stages[s] < 0 }
    when :GANLONBERRY, :KEEBERRY
	  usableItem = battler.pbCanRaiseStatStage?(:DEFENSE, battler)
    when :APICOTBERRY, :MARANGABERRY
	  usableItem = battler.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, battler)
    #---------------------------------------------------------------------------
    # HP healing items
    when :ORANBERRY, :SITRUSBERRY, :ENIGMABERRY, :BERRYJUICE, 
         :AGUAVBERRY, :FIGYBERRY, :IAPAPABERRY, :MAGOBERRY, :WIKIBERRY
      usableItem = battler.canHeal?
    #---------------------------------------------------------------------------
    # PP healing items
    when :LEPPABERRY, :HOPOBERRY      
      usableItem = battler.pokemon.moves.any? { |m| m.pp < m.total_pp }
    #---------------------------------------------------------------------------
    # Mental Herb
    when :MENTALHERB
      usableItem = !(battler.effects[PBEffects::Attract] == -1 &&
                     battler.effects[PBEffects::Taunt] == 0 &&
                     battler.effects[PBEffects::Encore] == 0 &&
                     !battler.effects[PBEffects::Torment] &&
                     battler.effects[PBEffects::Disable] == 0 &&
                     battler.effects[PBEffects::HealBlock] == 0)
    end
  end
  #-----------------------------------------------------------------------------
  if usableItem
    battle.pbDisplayBrief(_INTL("{1} was forced to consume its held {2}!", battler.pbThis, battler.itemName))
    battler.pbConsumeItem(true, false)
    battler.pbHeldItemTriggerCheck(item_id)
  else
    battle.pbDisplay(_INTL("But it failed!"))
  end
})

#-------------------------------------------------------------------------------
# Ability Urge
#-------------------------------------------------------------------------------
# Forces the target battler to reuse its ability, if possible.
#-------------------------------------------------------------------------------
ItemHandlers::UseInBattle.add(:ABILITYURGE, proc { |item, battler, battle|
  usableAbility = false
  abil = battler.ability_id
  if battler.abilityActive? && Battle::AbilityEffects::OnSwitchIn[abil]
    weather = battle.field.weather
    terrain = battle.field.terrain
    gen = Settings::MECHANICS_GENERATION
    case abil
    #---------------------------------------------------------------------------
    when :DOWNLOAD        then usableAbility = true
    when :FOREWARN        then usableAbility = battler.pbOwnedByPlayer?
    when :SUPERSWEETSYRUP then usableAbility = !battler.ability_triggered?
    when :DAUNTLESSSHIELD then usableAbility = (gen >= 9) ? !battler.ability_triggered? : true
    when :INTREPIDSWORD   then usableAbility = (gen >= 9) ? !battler.ability_triggered? : true
    when :INTIMIDATE      then usableAbility = (gen >= 9) ? battler.effects[PBEffects::OneUseAbility] != abil : true
    when :WINDRIDER       then usableAbility = battler.pbOwnSide.effects[PBEffects::Tailwind] > 0
    when :HOSPITALITY     then usableAbility = battler.allAllies.any? { |b| b.canHeal? }
    when :PASTELVEIL      then usableAbility = battler.allAllies.any? { |b| b.status == :POISON }
    when :CURIOUSMEDICINE then usableAbility = battler.allAllies.any? { |b| b.hasAlteredStatStages? }
    when :COSTAR          then usableAbility = battler.allAllies.any? { |b| b.hasAlteredStatStages? || b.effects[PBEffects::FocusEnergy] > 0}
    #---------------------------------------------------------------------------
    # Weather abilities
    when :DESOLATELAND    then usableAbility = weather != :HarshSun
    when :PRIMORDIALSEA   then usableAbility = weather != :HeavyRain
    when :DELTASTREAM     then usableAbility = weather != :StrongWinds
    when :DROUGHT         then usableAbility = ![:HarshSun, :HeavyRain, :StrongWinds, :Sun].include?(weather)
    when :ORICHALCUMPULSE then usableAbility = ![:HarshSun, :HeavyRain, :StrongWinds, :Sun].include?(weather)
    when :DRIZZLE         then usableAbility = ![:HarshSun, :HeavyRain, :StrongWinds, :Rain].include?(weather)
    when :SNOWWARNING     then usableAbility = ![:HarshSun, :HeavyRain, :StrongWinds, :Hail].include?(weather)
    when :SANDSTREAM      then usableAbility = ![:HarshSun, :HeavyRain, :StrongWinds, :Sandstorm].include?(weather)
    when :TERAFORMZERO    then usableAbility = !battler.ability_triggered? && (weather != :None || terrain != :None)
    #---------------------------------------------------------------------------
    # Terrain abilities
    when :GRASSYSURGE     then usableAbility = terrain != :Grassy
    when :MISTYSURGE      then usableAbility = terrain != :Misty
    when :PSYCHICSURGE    then usableAbility = terrain != :Psychic
    when :ELECTRICSURGE   then usableAbility = terrain != :Electric
    when :HADRONENGINE    then usableAbility = terrain != :Electric
    #---------------------------------------------------------------------------
    # Embody Aspect
    when :EMBODYASPECT, :EMBODYASPECT_1, :EMBODYASPECT_2, :EMBODYASPECT_3
      usableAbility = battler.isSpecies?(:OGERPON) && battler.effects[PBEffects::OneUseAbility] != abil
    #---------------------------------------------------------------------------
    # Screen Cleaner
    when :SCREENCLEANER
      [PBEffects::Reflect, PBEffects::LightScreen, PBEffects::AuroraVeil].each do |screen|
        if battler.pbOwnSide.effects[screen] > 0 || 
           battler.pbOpposingSide.effects[screen] > 0
          usableAbility = true
          break
        end
      end
    #---------------------------------------------------------------------------
    # Frisk
    when :FRISK
      if battler.pbOwnedByPlayer?
        items = battle.allOtherSideBattlers(battler.index).select { |b| b.item }
        usableAbility = items.length > 0
      end
    #---------------------------------------------------------------------------
    # Anticipation
    when :ANTICIPATION
      if battler.pbOwnedByPlayer?
        types = battler.pbTypes(true)
        battle.allOtherSideBattlers(battler.index).each do |b|
          b.eachMove do |m|
            next if m.statusMove?
            if types.length > 0
              moveType = m.type
              if gen >= 6 && m.function_code == "TypeDependsOnUserIVs"
                moveType = pbHiddenPower(b.pokemon)[0]
              end
              eff = Effectiveness.calculate(moveType, *types)
              next if Effectiveness.ineffective?(eff)
              next if !Effectiveness.super_effective?(eff) &&
                      !["OHKO", "OHKOIce", "OHKOHitsUndergroundTarget"].include?(m.function_code)
            elsif !["OHKO", "OHKOIce", "OHKOHitsUndergroundTarget"].include?(m.function_code)
              next
            end
            usableAbility = true
            break
          end
          break if usableAbility
        end
      end
    end
  end
  #-----------------------------------------------------------------------------
  if usableAbility
    battle.pbDisplayBrief(_INTL("{1} was forced to trigger its ability!", battler.pbThis))
    battler.pbTriggerAbilityOnGainingIt
  else
    battle.pbDisplay(_INTL("But it failed!"))
  end
})