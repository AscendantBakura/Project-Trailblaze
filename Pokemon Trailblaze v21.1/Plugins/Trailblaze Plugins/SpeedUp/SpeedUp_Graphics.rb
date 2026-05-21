module TrailblazeSpeedUp

  TIME_SWITCHES = {
		"morning"   => 184,
		"afternoon" => 185,
		"evening"   => 186,
		"night"     => 187
	}

  @@tb_turbo_icon = nil
  @@tb_opacity = 0
  @@tb_icon_until = 0

  def self.ensure_icon
    return if @@tb_turbo_icon && !@@tb_turbo_icon.disposed?
    @@tb_turbo_icon = Sprite.new(nil)
    @@tb_turbo_icon.ox = 0
    @@tb_turbo_icon.oy = 0
    @@tb_turbo_icon.x = 450
    @@tb_turbo_icon.y = 320
    @@tb_turbo_icon.z = 100_000
  rescue StandardError
    @@tb_turbo_icon = nil
  end

  def self.show_icon(frames = 6)
    ensure_icon
    return unless @@tb_turbo_icon
    time_icon = $game_switches ? TIME_SWITCHES.find { |_, id| $game_switches[id] }&.first : nil
    speed_icon = $PokemonSystem.tb_turbo_speed_multiplier ? $PokemonSystem.tb_turbo_speed_multiplier : 2.0
    icon = $speed_up ? "Graphics/Icons/turbo_on_#{time_icon}_#{speed_icon}.png" : nil
    resolved = pbResolveBitmap(icon)
    if resolved
      @@tb_turbo_icon.bitmap.dispose if @@tb_turbo_icon.bitmap && !@@tb_turbo_icon.bitmap.disposed?
      @@tb_turbo_icon.bitmap = Bitmap.new(resolved)
    end
    @@tb_opacity = 255
    @@tb_icon_until = Graphics.frame_count + [frames.to_i, 1].max
    pbSEPlay($speed_up ? "Correct" : "Incorrect", 20)
  rescue StandardError
  end

  def self.update_tick
    return unless @@tb_turbo_icon && !@@tb_turbo_icon.disposed?
    if Graphics.frame_count <= @@tb_icon_until
      @@tb_turbo_icon.opacity = @@tb_opacity
    else
      mult = (defined?(TrailblazeSpeedUp) && TrailblazeSpeedUp.respond_to?(:multiplier)) ? TrailblazeSpeedUp.multiplier : 1.0
      adjustment = $speed_up ? (1.0 / mult) : 1.0
      adjustment *= 3.5
      @@tb_opacity = [0, @@tb_opacity - adjustment].max
      @@tb_turbo_icon.opacity = @@tb_opacity
      if @@tb_opacity == 0
        if @@tb_turbo_icon.bitmap && !@@tb_turbo_icon.bitmap.disposed?
          @@tb_turbo_icon.bitmap.dispose
        end
      end
    end
  rescue StandardError
  end
end

module Graphics
  def self.turboIcon(force = false)
    TrailblazeSpeedUp.show_icon
  end

  def self.toggleTurbo
    if defined?(TrailblazeSpeedUp) && TrailblazeSpeedUp.respond_to?(:apply_turbo_state)
      TrailblazeSpeedUp.apply_turbo_state(!$speed_up)
    else
      $speed_up = !$speed_up
      if defined?($Settings) && $Settings.respond_to?(:turbo_speed_multiplier)
        Graphics.frame_rate = 40 * ($speed_up ? $Settings.turbo_speed_multiplier : 1)
      else
        Graphics.frame_rate = 40 * ($speed_up ? 2 : 1)
      end
    end
  end
end

class Scene_Map
  alias tb_speedup_scene_map_update update unless method_defined?(:tb_speedup_scene_map_update)
  def update
    tb_speedup_scene_map_update
    TrailblazeSpeedUp.update_tick if defined?(TrailblazeSpeedUp)
  end
end

if defined?(PokeBattle_Scene)
  class PokeBattle_Scene
    alias tb_speedup_pbGraphicsUpdate pbGraphicsUpdate unless method_defined?(:tb_speedup_pbGraphicsUpdate)
    def pbGraphicsUpdate
      tb_speedup_pbGraphicsUpdate
      TrailblazeSpeedUp.update_tick if defined?(TrailblazeSpeedUp)
    end
  end
end
