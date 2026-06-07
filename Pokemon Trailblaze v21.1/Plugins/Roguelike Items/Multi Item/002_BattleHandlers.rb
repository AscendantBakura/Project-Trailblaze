#-------------------------------------------------------------------------------
# All the edited battle handlers for multple items to function
#-------------------------------------------------------------------------------
module Battle::ItemEffects
  def self.override_item_trigger_methods
    arg1_methods = [
      "triggerPriorityBracketUse",
      "triggerDamageCalcFromUser",
      "triggerAfterMoveUseFromTarget",
      "triggerAfterMoveUseFromUser",
      "triggerEndOfRoundHealing",
      "triggerEndOfRoundEffect",
      "triggerOnSwitchIn",
      "triggerOnMissingTarget",
      "triggerOnOpposingStatGain"
    ]
    arg2_methods = [
      "triggerAccuracyCalcFromUser",
      "triggerDamageCalcFromTarget",
      "triggerOnBeingHit"
    ]
    arg3_methods = [
      "triggerAccuracyCalcFromTarget"
    ]
    methods = arg1_methods + arg2_methods + arg3_methods
    methods.each do |method|
      alias_name = "__roguelike__#{method}"
      next if Battle::ItemEffects.respond_to?(alias_name)
      next if !Battle::ItemEffects.respond_to?(method)
      Battle::ItemEffects.singleton_class.class_eval do
        alias_method alias_name, method
      end
      Battle::ItemEffects.define_singleton_method(method) do |*args|
        _, *rest = args
        if arg1_methods.include?(method)
          battler = args[1]
        elsif arg2_methods.include?(method)
          battler = args[2]
        elsif arg3_methods.include?(method)
          battler = args[3]
        end
        next if !battler || (battler.respond_to?(:itemActive?) && !battler.itemActive?)
        battler.each_item do |item|
          battler.display_item = item if battler.respond_to?(:display_item)
          send(alias_name, item, *rest)
          battler.display_item = nil if battler.respond_to?(:display_item)
        end
      end
    end
  end

  def self.override_item_trigger_methods_2
    methods = [
      "triggerStatusCure",
      "triggerOnBeingHitPositiveBerry",
      "triggerOnEndOfUsingMove",
      "triggerOnEndOfUsingMoveStatRestore",
      "triggerEVGainModifier",
      "triggerTerrainStatBoost",
      "triggerCertainSwitching",
      "triggerTrappingByTarget",
      "triggerStatLossImmunity",
      "triggerOnIntimidated",
      "triggerCertainEscapeFromBattle",
      "triggerOnStatLoss",
      "triggerHPHeal",
    ]
    methods.each do |method|
      alias_name = "__roguelike__#{method}"
      next if Battle::ItemEffects.respond_to?(alias_name)
      next if !Battle::ItemEffects.respond_to?(method)
      Battle::ItemEffects.singleton_class.class_eval do
        alias_method alias_name, method
      end
      Battle::ItemEffects.define_singleton_method(method) do |*args|
        _, *rest = args
        battler = args[1]
        next false if !battler || (battler.respond_to?(:itemActive?) && !battler.itemActive?)
        ret = false
        battler.each_item do |item|
          next if ret
          battler.display_item = item if battler.respond_to?(:display_item)
          ret = send(alias_name, item, *rest)
          battler.display_item = nil if battler.respond_to?(:display_item)
        end
        next ret
      end
    end
  end

  def self.override_item_trigger_methods_3
    arg1_methods = [
      "triggerSpeedCalc",
      "triggerWeightCalc",
      "triggerPriorityBracketChange",
      "triggerCriticalCalcFromUser",
      "triggerCriticalCalcFromTarget",
      "triggerExpGainModifier"
    ]
    arg2_methods = [
      "triggerCriticalCalcFromTarget"
    ]
    arg3_methods = [
      "triggerWeatherExtender",
      "triggerTerrainExtender"
    ]
    methods = arg1_methods + arg2_methods + arg3_methods
    methods.each do |method|
      alias_name = "__roguelike__#{method}"
      next if Battle::ItemEffects.respond_to?(alias_name)
      next if !Battle::ItemEffects.respond_to?(method)
      Battle::ItemEffects.singleton_class.class_eval do
        alias_method alias_name, method
      end
      Battle::ItemEffects.define_singleton_method(method) do |*args|
        _, *rest = args
        if arg1_methods.include?(method)
          battler = args[1]
        elsif arg2_methods.include?(method)
          battler = args[2]
        elsif arg3_methods.include?(method)
          battler = args[3]
        end
        base = send(alias_name, GameData::Item.get(:POKEBALL), *rest)
        next base if !battler || (battler.respond_to?(:itemActive?) && !battler.itemActive?)
        ret = base
        battler.each_item do |item|
          battler.display_item = item if battler.respond_to?(:display_item)
          ret = send(alias_name, item, *rest)
          battler.display_item = nil if battler.respond_to?(:display_item)
        end
        next ret
      end
    end
  end
end

Battle::ItemEffects.override_item_trigger_methods
Battle::ItemEffects.override_item_trigger_methods_2
Battle::ItemEffects.override_item_trigger_methods_3
