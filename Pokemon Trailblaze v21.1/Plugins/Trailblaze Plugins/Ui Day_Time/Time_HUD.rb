module TrailblazeTimeHUD
	ASSET_PATH = "Graphics/UI/PNGs for UI system/"
	DAY_PATH   = ASSET_PATH + "DAY ICONS/"
	TIME_PATH  = ASSET_PATH + "TIME ICONS/"

	# If we want to be able to toggle the HUD on/off, set this variable to the ID of a game variable that controls its visibility (currently set to time passed variable by default)
	SHOW_WHEN_VAR = 130

	# Change if we change or move the switches
	DAY_SWITCHES = {
		"MON" => 176,
		"TUE" => 177,
		"WED" => 178,
		"THU" => 179,
		"FRI" => 180,
		"SAT" => 181,
		"SUN" => 182
	}

	# Change if we change or move the switches
	TIME_SWITCHES = {
		"MORNING"   => 184,
		"AFTERNOON" => 185,
		"EVENING"   => 186,
		"NIGHT"     => 187
	}

	# Main HUD position on the screen
	HUD_X = 0
	HUD_Y = 0

	# Position and size of the 2 icons within the HUD
	DAY_SLOT_X = 44
	DAY_SLOT_Y = 6
	DAY_SLOT_W = 32
	DAY_SLOT_H = 14

	TIME_SLOT_X = 8
	TIME_SLOT_Y = 14
	TIME_SLOT_W = 32
	TIME_SLOT_H = 32

	module_function

	# Returns whether the HUD should be shown based on multiple factors (currently just whether the specified variable is on, but could be expanded in the future)
	def initialized?
		return false if !$game_variables
		return false if SHOW_WHEN_VAR < 0
		return $game_variables[SHOW_WHEN_VAR].to_i > 0
	end

	# Eating crayons and drawing stuff on the screen
	class HUD
		def initialize
			@viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
			@viewport.z = 99999
			@sprites = {}

			@sprites["frame"] = Sprite.new(@viewport)
			@sprites["frame"].bitmap = Bitmap.new(ASSET_PATH + "MAIN UI")
			@sprites["frame"].x = HUD_X
			@sprites["frame"].y = HUD_Y

			@sprites["overlay"] = BitmapSprite.new(@sprites["frame"].bitmap.width, @sprites["frame"].bitmap.height, @viewport)
			@sprites["overlay"].x = HUD_X
			@sprites["overlay"].y = HUD_Y

			@day_cache = {}
			@time_cache = {}
			@last_day_key = nil
			@last_time_key = nil

			refresh
			update_visibility
		end

		def dispose
			pbDisposeSpriteHash(@sprites)
			@viewport.dispose if @viewport && !@viewport.disposed?
		end

		def update
			update_visibility
			return if !visible?
			refresh_if_changed
			pbUpdateSpriteHash(@sprites)
		end

		def visible?
			return @sprites["frame"] && @sprites["frame"].visible
		end

		private

		def update_visibility
			show = TrailblazeTimeHUD.initialized?
			@sprites.each_value { |s| s.visible = show if s }
		end

		def refresh_if_changed
			day_key = current_day_key
			time_key = current_time_key
			return if day_key == @last_day_key && time_key == @last_time_key
			@last_day_key = day_key
			@last_time_key = time_key
			refresh
		end

		def refresh
			return if !@sprites["overlay"] || !@sprites["overlay"].bitmap
			bmp = @sprites["overlay"].bitmap
			bmp.clear

			day_icon = load_day_icon(current_day_key)
			time_icon = load_time_icon(current_time_key)

			if day_icon
				bmp.stretch_blt(
					Rect.new(DAY_SLOT_X, DAY_SLOT_Y, DAY_SLOT_W, DAY_SLOT_H),
					day_icon,
					Rect.new(0, 0, day_icon.width, day_icon.height)
				)
			end

			if time_icon
				bmp.stretch_blt(
					Rect.new(TIME_SLOT_X, TIME_SLOT_Y, TIME_SLOT_W, TIME_SLOT_H),
					time_icon,
					Rect.new(0, 0, time_icon.width, time_icon.height)
				)
			end
		end

		def current_day_key
			DAY_SWITCHES.each do |name, id|
				return name if $game_switches[id]
			end
			return nil
		end

		def current_time_key
			TIME_SWITCHES.each do |name, id|
				return name if $game_switches[id]
			end
			return nil
		end

		def load_day_icon(key)
			return nil if !key
			@day_cache[key] ||= begin
				file = DAY_PATH + key
				if pbResolveBitmap(file)
					Bitmap.new(file)
				else
					nil
				end
			end
		end

		def load_time_icon(key)
			return nil if !key
			@time_cache[key] ||= begin
				file = TIME_PATH + key
				if pbResolveBitmap(file)
					Bitmap.new(file)
				else
					nil
				end
			end
		end
	end
end

# What actually draws all the stuff on the screen at the right times and disposes of it when we leave the map, etc. it's best not to mess with this unless you know what you're doing, but feel free to ask if you want to change something about how/when the HUD appears or disappears or updates, etc.
class Scene_Map
	def ensure_trailblaze_time_hud
		return if @trailblaze_time_hud
		@trailblaze_time_hud = TrailblazeTimeHUD::HUD.new
	end

	if method_defined?(:start)
		alias trailblaze_time_hud_start start unless method_defined?(:trailblaze_time_hud_start)
		def start
			trailblaze_time_hud_start
			ensure_trailblaze_time_hud
		end
	end

	alias trailblaze_time_hud_update update unless method_defined?(:trailblaze_time_hud_update)
	def update
		trailblaze_time_hud_update
		ensure_trailblaze_time_hud
		@trailblaze_time_hud&.update
	end

	if method_defined?(:terminate)
		alias trailblaze_time_hud_terminate terminate unless method_defined?(:trailblaze_time_hud_terminate)
		def terminate
			@trailblaze_time_hud&.dispose
			@trailblaze_time_hud = nil
			trailblaze_time_hud_terminate
		end
	end
end
