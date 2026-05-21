module Input
  class << self
    alias tb_speedup_update update unless method_defined?(:tb_speedup_update)
  end

  def self.tb_turbo_toggle_pressed?
    return false if Input.text_input
    return true if defined?(Input::AUX1) && trigger?(Input::AUX1)
    return true if defined?(Input::E) && trigger?(Input::E)
    false
  end

  def self.tb_dynamic_turbo_update
    return unless defined?(Input::Controller) && Input::Controller.respond_to?(:axes_trigger)
    axes = Input::Controller.axes_trigger
    return if !axes || axes.empty?
    trigger_value = axes[0].to_f
    trigger_value = 0.0 if trigger_value.abs < 0.08
    pbDynamicTurbo(trigger_value)
  rescue StandardError
  end

  def self.update
    tb_speedup_update
    if tb_turbo_toggle_pressed?
      Graphics.toggleTurbo
      Graphics.turboIcon
    end
    tb_dynamic_turbo_update
  end
end

def pbDynamicTurbo(value)
  return if value.nil?
  clamped = [[value.to_f, 0.0].max, 1.0].min
  clamped = 1.0 - clamped if $speed_up
  mult = TrailblazeSpeedUp.multiplier
  TrailblazeSpeedUp.set_runtime_multiplier(1 + (clamped * (mult - 1)))
end
