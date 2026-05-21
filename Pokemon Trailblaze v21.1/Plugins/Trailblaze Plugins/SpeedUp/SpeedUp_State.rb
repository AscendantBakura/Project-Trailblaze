$speed_up = false if !defined?($speed_up) || $speed_up.nil? #
$tb_runtime_speed_multiplier = 1.0 if !defined?($tb_runtime_speed_multiplier) || $tb_runtime_speed_multiplier.nil?
$tb_scaled_uptime = nil if !defined?($tb_scaled_uptime)
$tb_last_unscaled_uptime = nil if !defined?($tb_last_unscaled_uptime)

module TrailblazeSpeedUp
  def self.multiplier
    value = nil
    value = $PokemonSystem.tb_turbo_speed_multiplier if $PokemonSystem && $PokemonSystem.respond_to?(:tb_turbo_speed_multiplier)
    value = DEFAULT_TURBO_MULTIPLIER if value.nil?
    value = value.to_f
    value = 1.0 if value < 1.0
    return value
  end

  def self.frameskip_enabled?
    return false if !$PokemonSystem || !$PokemonSystem.respond_to?(:tb_turbo_frameskip)
    return $PokemonSystem.tb_turbo_frameskip.to_i == 1
  end

  def self.apply_frameskip
    Graphics.frameskip = frameskip_enabled?
  end

  def self.runtime_multiplier
    value = $tb_runtime_speed_multiplier
    value = 1.0 if value.nil?
    value = value.to_f
    value = 1.0 if value < 1.0
    return value
  end

  def self.set_runtime_multiplier(value)
    amount = value.to_f
    amount = 1.0 if amount < 1.0
    $tb_runtime_speed_multiplier = amount
    Graphics.frame_rate = BASE_FRAME_RATE * amount
  end

  # Animation cancelling fix
  def self.scaled_uptime(unscaled_now)
    now = unscaled_now.to_f
    $tb_scaled_uptime = now if $tb_scaled_uptime.nil?
    $tb_last_unscaled_uptime = now if $tb_last_unscaled_uptime.nil?

    delta = now - $tb_last_unscaled_uptime
    if delta < 0
      $tb_last_unscaled_uptime = now
      return $tb_scaled_uptime
    end

    $tb_scaled_uptime += delta * runtime_multiplier
    $tb_last_unscaled_uptime = now
    return $tb_scaled_uptime
  end

  def self.reset_scaled_uptime_reference(unscaled_now = nil)
    now = unscaled_now
    now = System.tb_speedup_unscaled_uptime if now.nil? && System.respond_to?(:tb_speedup_unscaled_uptime)
    now = now.to_f
    $tb_scaled_uptime = now if $tb_scaled_uptime.nil?
    $tb_last_unscaled_uptime = now
  end

  def self.apply_turbo_state(enabled)
    $speed_up = enabled ? true : false
    set_runtime_multiplier($speed_up ? multiplier : 1.0)
  end
end

module System
  class << self
    alias tb_speedup_unscaled_uptime uptime unless method_defined?(:tb_speedup_unscaled_uptime)
  end

  def self.uptime
    return TrailblazeSpeedUp.scaled_uptime(tb_speedup_unscaled_uptime)
  end
end

class PokemonSystem
  alias tb_speedup_initialize initialize unless method_defined?(:tb_speedup_initialize)
  attr_accessor :tb_turbo_speed_multiplier
  attr_accessor :tb_turbo_frameskip

  def initialize
    tb_speedup_initialize
    @tb_turbo_speed_multiplier = TrailblazeSpeedUp::DEFAULT_TURBO_MULTIPLIER if @tb_turbo_speed_multiplier.nil?
    @tb_turbo_frameskip = TrailblazeSpeedUp::DEFAULT_FRAMESKIP if @tb_turbo_frameskip.nil?
  end
end

EventHandlers.add(:on_startup, :tb_speedup_apply_initial_state, proc {
  TrailblazeSpeedUp.apply_frameskip
  TrailblazeSpeedUp.apply_turbo_state($speed_up)
  TrailblazeSpeedUp.reset_scaled_uptime_reference
})
