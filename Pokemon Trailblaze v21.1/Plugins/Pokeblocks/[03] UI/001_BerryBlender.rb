#===============================================================
#  Berry Blender Commands
#===============================================================
def pbBerryBlender(playerCount=0,specificNames=nil,forceFail=false)
	if PokeblockSettings::SIMPLIFIED_BERRY_BLENDING
		Console.echo_warn _INTL("SIMPLIFIED_BERRY_BLENDING is set to true, but pbBerryBlender was called. Running pbBerryBlender, instead.")
		return pbBerryBlenderSimple
		
	end
	if !$bag.hasAnyBerry?
		pbMessage(_INTL("You don't have any berries!"))
		return false
	end
	ret = false
	pbFadeOutIn {
		scene = BerryBlender_Scene.new
		screen = BerryBlender_Screen.new(scene)
		ret = screen.pbStartScreen(playerCount,specificNames,forceFail)
	}
	return ret
end

def pbBerryBlenderSimple
	if !$bag.hasAnyBerry?
		pbMessage(_INTL("You don't have any berries!"))
		return false
	end
	ret = false
	pbFadeOutIn {
		scene = SimpleBerryBlender_Scene.new
		screen = BerryBlender_Screen.new(scene)
		ret = screen.pbStartScreenSimple
	}
	return ret
end

#===============================================================================
# Berry Blender Scene
#=============================================================================== 

class BerryBlender_Screen
  def initialize(scene)
    @scene = scene
  end

  def pbStartScreen(playerCount,specificNames,forceFail)
	  @play = true
    @scene.pbStartScene(playerCount,specificNames,forceFail)
    while @play
      @play = @scene.pbScene
      @scene.reset_parameter(true) if @play
    end
    @scene.pbEndScene
    return true
  end

  def pbStartScreenSimple
	@play = true
    @scene.pbStartScene
    while @play
			@play = @scene.pbScene
			@scene.reset_parameter(true) if @play
		end
    @scene.pbEndScene
    return true
  end
end

class BerryBlender_Scene
	include BopModule

	MIN_RPM = 7.03
	RPM_DROP_PER_SECOND = 0.66
  
  #== Scene ========================================================================================================
	def pbStartScene(playerCount,specificNames,forceFail)
		# Viewport
		@viewport = Viewport.new(0,0,Graphics.width,Graphics.height)
		@viewport.z = 99999
		# Values
		# Set number to define player, quantity of players
		@playerCount = playerCount
		@forceFail = forceFail
		# Set name
		@name = []
		@name << $player.name
		if playerCount != 0 && playerCount != 4
			a = 0
			playerCount.times { 
				if specificNames && specificNames[a]
					@name << specificNames[a]
				else
					@name << PokeblockSettings::NPC_DEFAULT_NAMES[a].sample
				end
				a += 1
			} 
		elsif playerCount == 4
			if specificNames && specificNames[0]
				@name << specificNames[0]
			else
				@name << PokeblockSettings::NPC_DEFAULT_NAMES[3].sample
			end
		end
		reset_parameter
	end
	
	def reset_parameter(restarted = false)
		@restarted = restarted if restarted
		# Sprites
		@sprites = {}
		# Store berry
		@berry = []
		# Set speed of circle
		@current_rpm = MIN_RPM	# speed (RPM)
		@maxSpeed = 0 					# max speed (RPM)
		# Count good, miss, perfect
		@count = {}
		@showFeature = {}
		@pressCheck  = []
		@name.each { |name|
			@count[name] = { perfect: 0, good: 0, miss: 0 }
			@showFeature[name] = { perfect: [], good: [], miss: [] }
			# Use to check if player press (AI)
			@pressCheck << false
		}
		@showEffect = false
		@trigger_effect = {}
		# trigger effect [visibility, timer]
		10.times { |i| @trigger_effect[i] = nil }
		# Result (show result)
		@result = false
		@checkall = false
		@showPage = 0
		# Set name of flavor after playing
		@flavorGet = []
		# Set order
		@order = nil
		@orderNum = []
		# Fade
		@fade = false
		@countFade = 0
		# Finish
		@exit = false
		@sprites["circle"]&.angle = 0
	end
	
	def pbScene
		# Create
		create_scene
		# Draw name and animation
		draw_name
		# Fade
		pbFadeInAndShow(@sprites) { update } if !@restarted
		# Choose berry
		notplay = false
		berry   = nil
		if @restarted then @restarted = nil;
		else
			pbMessage(_INTL("Starting up the Berry Blender...")) 
			pbMessage(_INTL("Please select a berry from your bag to put in the Berry Blender."))
		end
		loop do
			berry = BerryPoffin.pbPickBerryForBlender
			if berry.nil? || berry == 0
				notplay = !pbConfirmMessage(_INTL("Do you want to choose a berry?"))
				break if notplay
			else
				break
			end
		end
		return if notplay
		# Set berry
		@berry << berry
		@berry.concat(getAIBerries(berry,@playerCount))
		# Animation berry
		@berry.each_with_index { |b, i| animationBerry(b, i) }
		# Zoom
		zoom_circle_before_start
		# Count
		count_and_start
		loop do
			update_ingame
			break if @exit
			# Fade
			fade_out if @countFade == 2
			# Update
			update_main
			# Draw text
			draw_main
			# Input
			set_input
		end
		return true if $bag.hasAnyBerry? && pbConfirmMessage(_INTL("Would you like to blend another berry?"))
		return false
	end
	
	def pbEndScene
		pbFadeOutAndHide(@sprites) { update }
		pbDisposeSpriteHash(@sprites)
		@viewport.dispose
	end

	#--------------#
	# Create scene #
	#--------------#
	def create_scene
		# Create scene
		create_sprite("behind", "Behind", @viewport)
		# Create time bar
		create_sprite("time bar", "Time", @viewport)
		x = 188 - @sprites["time bar"].bitmap.width
		y = 5
		set_xy_sprite("time bar", x, y)
		# Last is player and special
		arr = ["OnePlayer", "TwoPlayers", "ThreePlayers", "FourPlayers", "TwoPlayers"]
		create_sprite("scene", arr[@playerCount], @viewport)
		# Name text (playing)
		create_sprite_2("name text", @viewport)
		# Speed text (playing)
		create_sprite_2("speed text", @viewport)
		# Create circle
		create_sprite("circle", "Circle", @viewport)
		ox = @sprites["circle"].bitmap.width / 2
		oy = @sprites["circle"].bitmap.height / 2
		set_oxoy_sprite("circle", ox, oy)
		x = Graphics.width / 2
		y = Graphics.height / 2
		set_xy_sprite("circle", x, y)
		set_zoom_sprite("circle", 3, 3)
		set_visible_sprite("circle")
		# Create number
		create_sprite("number icon", "3", @viewport)
		ox = @sprites["number icon"].bitmap.width / 2
		oy = @sprites["number icon"].bitmap.height / 2
		set_oxoy_sprite("number icon", ox, oy)
		set_xy_sprite("number icon", x, y)
		set_visible_sprite("number icon")
		# Start (image)
		create_sprite("start icon", "Start", @viewport)
		ox = @sprites["start icon"].bitmap.width / 2
		oy = @sprites["start icon"].bitmap.height / 2
		set_oxoy_sprite("start icon", ox, oy)
		set_xy_sprite("start icon", x, y)
		set_visible_sprite("start icon")
		# Effect
		draw_effect
		# Result (scene)
		create_sprite("result scene", "results", @viewport)
		set_visible_sprite("result scene")
		# Text
		create_sprite_2("result text", @viewport)
		create_sprite_2("result icon text", @viewport)
	end
		
#== Berry Input ==================================================================================================================
	def getAIBerries(playerBerry,playerCount)
		return [] if playerCount == 0
		arr = []
		if PokeblockSettings::NPC_USE_RANDOM_BERRIES
			if playerCount == 4
				arr << PokeblockSettings::BERRY_MASTER_BERRIES.sample
			else
				playerCount.times { arr << GameData::BerryData.keys.sample }
			end
		else
			if playerCount == 4 #Berry Master
				case playerBerry
				#General Cases
				when :CHERIBERRY,:ENIGMABERRY,:LEPPABERRY,:FIGYBERRY,:RAZZBERRY,:POMEGBERRY,:TAMATOBERRY,
						:OCCABERRY,:CHOPLEBERRY,:TANGABERRY,:BABIRIBERRY,:LIECHIBERRY,:LANSATBERRY
					arr.push(:SPELONBERRY)
				when :CHESTOBERRY,:ORANBERRY,:WIKIBERRY,:BLUKBERRY,:KELPSYBERRY,:CORNNBERRY,:PASSHOBERRY,
						:KEBIABERRY,:CHARTIBERRY,:CHILANBERRY,:GANLONBERRY,:MICLEBERRY,:KEEBERRY,:STARFBERRY
					arr.push(:PAMTREBERRY)
				when :PECHABERRY,:PERSIMBERRY,:MAGOBERRY,:NANABBERRY,:QUALOTBERRY,:MAGOSTBERRY,:WACANBERRY,
						:SHUCABERRY,:KASIBBERRY,:SALACBERRY,:CUSTAPBERRY,:ROSELIBERRY
					arr.push(:WATMELBERRY)
				when :RAWSTBERRY,:LUMBERRY,:AGUAVBERRY,:WEPEARBERRY,:HONDEWBERRY,:RABUTABERRY,:RINDOBERRY,
						:COBABERRY,:HABANBERRY,:PETAYABERRY,:JABOCABERRY,:MARANGABERRY
					arr.push(:DURINBERRY)
				when :ASPEARBERRY,:SITRUSBERRY,:IAPAPABERRY,:PINAPBERRY,:GREPABERRY,:NOMELBERRY,:YACHEBERRY,
						:COLBURBERRY,:APICOTBERRY,:ROWAPBERRY
					arr.push(:BELUEBERRY)
				#Special Cases
				when :SPELONBERRY
					arr.push(:TAMATOBERRY)
				when :PAMTREBERRY
					arr.push(:CORNNBERRY)
				when :WATMELBERRY
					arr.push(:MAGOSTBERRY)
				when :DURINBERRY
					arr.push(:RABUTABERRY)
				when :BELUEBERRY
					arr.push(:NOMELBERRY)
				end
			else
				case playerBerry
				#General Cases
				when :LEPPABERRY,:FIGYBERRY,:RAZZBERRY,:POMEGBERRY,:TAMATOBERRY,:SPELONBERRY,
						:OCCABERRY,:CHOPLEBERRY,:TANGABERRY,:BABIRIBERRY,:LIECHIBERRY,:LANSATBERRY,:ENIGMABERRY
					arr.push(:CHERIBERRY,:PECHABERRY,:RAWSTBERRY)
				when :ORANBERRY,:WIKIBERRY,:BLUKBERRY,:KELPSYBERRY,:CORNNBERRY,:PAMTREBERRY,
						:PASSHOBERRY,:KEBIABERRY,:CHARTIBERRY,:CHILANBERRY,:GANLONBERRY,:MICLEBERRY,:KEEBERRY,:STARFBERRY
					arr.push(:CHESTOBERRY,:RAWSTBERRY,:ASPEARBERRY)
				when :PERSIMBERRY,:MAGOBERRY,:NANABBERRY,:QUALOTBERRY,:MAGOSTBERRY,:WATMELBERRY,
						:WACANBERRY,:SHUCABERRY,:KASIBBERRY,:SALACBERRY,:CUSTAPBERRY,:ROSELIBERRY
					arr.push(:PECHABERRY,:ASPEARBERRY,:CHERIBERRY)
				when :LUMBERRY,:AGUAVBERRY,:WEPEARBERRY,:HONDEWBERRY,:RABUTABERRY,:DURINBERRY,
						:RINDOBERRY,:COBABERRY,:HABANBERRY,:PETAYABERRY,:JABOCABERRY,:MARANGABERRY
					arr.push(:RAWSTBERRY,:CHERIBERRY,:CHESTOBERRY)
				when :SITRUSBERRY,:IAPAPABERRY,:PINAPBERRY,:GREPABERRY,:NOMELBERRY,:BELUEBERRY,
						:YACHEBERRY,:COLBURBERRY,:APICOTBERRY,:ROWAPBERRY
					arr.push(:ASPEARBERRY,:CHESTOBERRY,:PECHABERRY)
				#Special Cases
				when :CHERIBERRY
					arr.push(:ASPEARBERRY,:RAWSTBERRY,:PECHABERRY)
				when :CHESTOBERRY
					arr.push(:CHERIBERRY,:ASPEARBERRY,:RAWSTBERRY)
				when :PECHABERRY
					arr.push(:CHESTOBERRY,:CHERIBERRY,:ASPEARBERRY)
				when :RAWSTBERRY
					arr.push(:PECHABERRY,:CHESTOBERRY,:CHERIBERRY)
				when :ASPEARBERRY
					arr.push(:RAWSTBERRY,:PECHABERRY,:CHESTOBERRY)
				end
			end
		end 
		arr.pop if playerCount == 2
		arr.pop(2) if playerCount == 1
		return arr
	end
	
#=== Sprites =======================================================================================================================
	#------------#
	# Set bitmap #
	#------------#
	# Image
	def create_sprite(spritename,filename,vp,dir="")
		@sprites["#{spritename}"] = Sprite.new(vp)
		folder = "Pokeblock/UI Berry Blender"
		file = dir ? "Graphics/UI/#{folder}/#{dir}/#{filename}" : "Graphics/UI/#{folder}/#{filename}"
		@sprites["#{spritename}"].bitmap = Bitmap.new(file)
	end

	def set_sprite(spritename,filename,dir="")
		folder = "Pokeblock/UI Berry Blender"
		file = dir ? "Graphics/UI/#{folder}/#{dir}/#{filename}" : "Graphics/UI/#{folder}/#{filename}"
		@sprites["#{spritename}"].bitmap = Bitmap.new(file)
	end

	#------#
	# Text #
	#------#
	# Draw
	def create_sprite_2(spritename,vp)
		@sprites["#{spritename}"] = Sprite.new(vp)
		@sprites["#{spritename}"].bitmap = Bitmap.new(Graphics.width,Graphics.height)
	end

	# Write
	def drawTxt(bitmap, textpos)
		# Sprite
		bitmap = @sprites["#{bitmap}"].bitmap
		bitmap.clear
		pbSetSystemFont(bitmap)
		pbDrawTextPositions(bitmap,textpos)
	end

	# Clear
	def clearTxt(bitmap)
		@sprites["#{bitmap}"].bitmap.clear
	end

	#===============================================================
	#  6 - Draw Text
	#===============================================================
	BASE_COLOR = MessageConfig::DARK_TEXT_MAIN_COLOR
	SHADOW_COLOR = MessageConfig::DARK_TEXT_SHADOW_COLOR
	
	def draw_name
		text = []
		time = @playerCount != 4 ? (@playerCount + 1) : 2
		time.times { |i|
			string = @name[i]
			x = 15 + 358 * (i % 2) + 5
			y = 113 - 10 + 11 + 115 * (i / 2)
			text << [string, x, y, 0, BASE_COLOR, SHADOW_COLOR]
		}
		drawTxt("name text", text)
	end

	#-----------#
	# Draw text #
	#-----------#
	def draw_main
		draw_speed
		draw_result
	end

	def draw_speed
		clearTxt("speed text")
		return if @result
		text = []
		string = "#{@current_rpm.truncate(2)}"
		x = 210 + 46
		y = 330 - 4
		text << [string, x, y, 2, BASE_COLOR, SHADOW_COLOR]
		drawTxt("speed text", text)
	end

	def draw_result
		clearTxt("result text")
		return unless @result
		clearTxt("name text")
		# Draw bitmap
		draw_bitmap_features_text
		# Draw name, berry
		draw_players_text
	end

	def draw_bitmap_features_text
		clearTxt("result icon text")
		return if @showPage == 1
		arr = ["Perfect","Good","Miss"]
		bitmap = @sprites["result icon text"].bitmap
		imgpos = []
		arr.each_with_index { |a, i| imgpos << [ "Graphics/UI/Pokeblock/UI Berry Blender/#{a}", 240 + 80 * i, 90 + 4, 0, 0, -1, -1 ] }
		pbDrawImagePositions(bitmap, imgpos)
	end

	def draw_players_text
		bitmap = @sprites["result text"].bitmap
		maxy = 0
		text = []
		# Max speed
		string = "Max speed: #{@maxSpeed.truncate(2)} RPM"
		x = (Graphics.width - bitmap.text_size(string).width) / 2
		y = 48 + 6
		text << [string, x, y, 0, BASE_COLOR, SHADOW_COLOR]
		# Order
		@order.each_with_index { |order, i|
			string = "#{@orderNum[i]}. #{order[0][0]}"
			x = 5
			y = 130 + (20 + 26) * i
			maxy = y if maxy < y
			text << [string, x, y, 0, BASE_COLOR, SHADOW_COLOR]
			if @showPage == 1
				string = GameData::Item.get(order[0][1]).name
				x = 240
				text << [string, x, y, 0, BASE_COLOR, SHADOW_COLOR]
			end
			next if @showPage != 0
			order[0][2].each_with_index { |a, j|
				string = "#{a}"
				x = 240 + 16 + 80 * j
				text << [string, x, y, 2, BASE_COLOR, SHADOW_COLOR]
			}
		}
		# Flavor name
		flavorName = @flavorGet[0]
		flavorLevel = @flavorGet[1]
		flavorFeel = @flavorGet[2]
		string = "You got a #{flavorName} Pokéblock"
		string2 = "Lv. #{flavorLevel}   Feel #{flavorFeel}"
		#x = (Graphics.width - bitmap.text_size(string).width) / 2
		x = Graphics.width/2
		y = maxy + 40
		text << [string, x, y, 2, BASE_COLOR, SHADOW_COLOR]
		text << [string2, x, y+32, 2, BASE_COLOR, SHADOW_COLOR]
		drawTxt("result text", text)
	end
  
#= Update =================================================================================================================

	# Dispose
	def dispose(id=nil)
	  (id.nil?)? pbDisposeSpriteHash(@sprites) : pbDisposeSprite(@sprites,id)
	end
	
	# Update (just script)
	def update
	  pbUpdateSpriteHash(@sprites)
	end

	# Update
	def update_ingame
	  Graphics.update
	  Input.update
	  pbUpdateSpriteHash(@sprites)
	end

	# Main update
	def update_main
		update_circle
		update_features
		update_effect
		update_time_bar_auto
		if @result
			set_visible_sprite("result scene", true)
			# Draw result
			draw_result
			return if @countFade == 2
			# Increase count
			@countFade += 1
		end
	end

#=== Animations ====================================================================================================================
	#----------------#
	# Zoom in circle #
	#----------------#
	def zoom_circle_before_start
		set_visible_sprite("circle", true)
		num = 0.5
		4.times { |i|
			update_ingame
			@sprites["circle"].zoom_x -= num
			@sprites["circle"].zoom_y -= num
		}
		pbSEPlay("Battle catch click",100,100)
	end

	#----------------#
	# Count to start #
	#----------------#
	def count_and_start
		number = 2
		pbWait(0.5)
		set_visible_sprite("number icon", true)
		pbSEPlay("Berry Blender Countdown", 100, 100)
		pbWait(0.5)
		2.times { |i|
			update_ingame
			set_sprite("number icon", "#{number}")
			pbSEPlay("Berry Blender Countdown", 100, 100)
			pbWait(0.5)
			number -= 1
		}
		set_visible_sprite("number icon")
		set_visible_sprite("start icon", true)
		pbSEPlay("Berry Blender Start", 100, 100)
		pbWait(0.5)
		set_visible_sprite("start icon")
	end

	#---------------------------------#
	# Set feature perfect, good, miss #
	#---------------------------------#
	# pos: define player
	# angle: angle to define position of bitmap
	def angle_circle(method, angle, pos=0)
		# Update speed
		change_rpm(method)
		case method
		when :perfect # Perfect
			# Increase feature
			@count[@name[pos]][:perfect] += 1
			# Show effect
			@showEffect = true
			# Update time bar
			update_time_bar(6)
			# Draw bitmap
			draw_perfect_good_miss(angle, 0, pos)
			pbSEPlay("Berry Blender Perfect", 100, 100)
		when :good # Good
			# Increase feature
			@count[@name[pos]][:good] += 1
			# Update time bar
			update_time_bar(3)
			# Draw bitmap
			draw_perfect_good_miss(angle, 1, pos)
			pbSEPlay("Berry Blender Good", 100, 100)
		when :miss # Miss
			# Increase feature
			@count[@name[pos]][:miss] += 1
			# Draw bitmap
			draw_perfect_good_miss(angle, 2, pos)
			pbSEPlay("Berry Blender Miss", 100, 100)
		end
	end

	# Draw bitmap #
	FEATURE_VISIBLE_FALSE = 5
	def draw_perfect_good_miss(angle, feature=0, pos=0)
		arr  = ["Perfect", "Good", "Miss"]
		name = feature == 0 ? :perfect : feature == 1 ? :good : :miss
		spritename = "#{arr[feature]} #{@count[@name[pos]][name]}"
		return if @sprites[spritename]
		create_sprite(spritename, arr[feature], @viewport)
		ox = @sprites[spritename].bitmap.width / 2
		oy = @sprites[spritename].bitmap.height / 2
		set_oxoy_sprite(spritename, ox, oy)
		x = angle == 40 || angle == 140 ? 186 : 326
		y = angle == 40 || angle == 320 ? 113 : 271
		set_xy_sprite(spritename, x, y)
		@showFeature[@name[pos]][name] << FEATURE_VISIBLE_FALSE
	end

	# Draw effect when press perfect #
	def draw_effect
		2.times { |j|
			10.times { |i|
				create_sprite("effect #{j} #{i}", "Effect_#{j+1}", @viewport)
				ox = @sprites["effect #{j} #{i}"].bitmap.width / 2
				oy = @sprites["effect #{j} #{i}"].bitmap.height / 2
				set_oxoy_sprite("effect #{j} #{i}", ox, oy)
				set_visible_sprite("effect #{j} #{i}")
			}
		}
	end

	#------#
	# Fade #
	#------#
	def fade_in
		return if @fade
    timer_start = System.uptime
    loop do
      alpha = lerp(0, 255, 1, timer_start, System.uptime)
      @viewport.color = Color.new(0, 0, 0, alpha)
			Graphics.update
      break if alpha >= 255
    end		
		@fade = true
	end

	def fade_out
		return unless @fade
    timer_start = System.uptime
    loop do
      alpha = lerp(255, 0, 1, timer_start, System.uptime)
      @viewport.color = Color.new(0, 0, 0, alpha)
			Graphics.update
      break if alpha <= 0
    end	
		@fade = false
	end

	#---------------------------------#
	# Berry Animation                 #
	#---------------------------------#
	# Pos = position of player's berry -> 0: Player, 1: AI-1, 2: AI-2, 3: AI-3, 
	def animationBerry(berrynumber, pos=0)
		if !@sprites["berry #{pos}"]
			begin
				filename = GameData::Item.icon_filename(berrynumber)
			rescue 
				p "You have an error when choosing berry"
				Kernel.exit!
			end
			@sprites["berry #{pos}"] = Sprite.new(@viewport)
			@sprites["berry #{pos}"].bitmap = Bitmap.new(filename)
			ox = @sprites["berry #{pos}"].bitmap.width/2
			oy = @sprites["berry #{pos}"].bitmap.height/2
			set_oxoy_sprite("berry #{pos}",ox,oy)
			x = Graphics.width / 2 + (pos==0 || pos==2 ? -Graphics.height/2 : Graphics.height/2)
			y = pos==0 || pos==1 ? 0 : Graphics.height
			set_xy_sprite("berry #{pos}",x,y)
			x0 = x
			y0 = y
		end
		t = 0
		loop do
			Graphics.update
			update
			if pos==0 || pos==1
				break if @sprites["berry #{pos}"].y >= (Graphics.height/2-10)
			else
				break if @sprites["berry #{pos}"].y <= (Graphics.height/2+10)
			end
			r = Graphics.height/4*Math.sqrt(2)
			t += 0.05
			case pos
			when 0
				x =  r*(1-Math.cos(t))
				y =  r*(t-Math.sin(t))
			when 1
				x = -r*(1-Math.cos(t))
				y =  r*(t-Math.sin(t))
			when 2
				x =  r*(t-Math.sin(t))
				y = -r*(1-Math.cos(t))
			when 3
				x = -r*(t-Math.sin(t))
				y = -r*(1-Math.cos(t))
			end
			x += x0
			y += y0
			set_xy_sprite("berry #{pos}", x, y)
		end
		dispose("berry #{pos}")
	end

	#-------------#
	# Turn circle #
	#-------------#
	def update_circle
		# Timer to slowdown the cirle
		@timer = System.uptime if !@timer
		if System.uptime - @timer >= 1
			@current_rpm -= RPM_DROP_PER_SECOND if @current_rpm > MIN_RPM
			@current_rpm  = MIN_RPM if @current_rpm < MIN_RPM
			@timer = System.uptime
		end
		# Update angle
		update_angle_circle
	end

	def deaccelerate_circle
		duration = 1
		start_rpm = @current_rpm
		timer = System.uptime
		loop do
			update_ingame
			current_rpm = lerp(start_rpm, 0, duration, timer, System.uptime)
			angle = (current_rpm * 360) / (60.0 * Graphics.frame_rate)
			# Update circle sprite
			@sprites["circle"].angle += angle
			@sprites["circle"].angle %= 360
			break if current_rpm == 0
		end
	end

	def update_angle_circle
		angle = (@current_rpm * 360) / (60.0 * Graphics.frame_rate)
		# Reset AI input after the circle spin pass 360
		reset_AI_input if @sprites["circle"].angle + angle >= 360
		# Update circle sprite
		@sprites["circle"].angle += angle
		@sprites["circle"].angle %= 360
	end

	def change_rpm(method)
		player_count = [@playerCount + 1, 4].min
		case method
		when :perfect
			@current_rpm += (@current_rpm < 82.39 ? 21.09 : 7.03) / player_count
		when :good
			@current_rpm += (@current_rpm < 82.39 ? 14.06 : 0) / player_count
		when :miss
			@current_rpm -= 14.06 / player_count
		end
		@current_rpm = 7.03 if @current_rpm < 7.03
		@maxSpeed = [@maxSpeed, @current_rpm].max
	end

	#--------#
	# Effect #
	#--------#
	def update_effect
		if @result
			2.times { |j|
				10.times { |i| set_visible_sprite("effect #{j} #{i}") }
			}
		else
			@trigger_effect.each { |k, v|
				next unless @trigger_effect[k]
				next if System.uptime - @trigger_effect[k] < 0.8 # 0.8 second
				2.times { |i| set_visible_sprite("effect #{i} #{k}") }
				@trigger_effect[k] = nil
			}
			return unless @showEffect
			random1 = rand(10)
			@showEffect = false
			return if @trigger_effect[random1]
			2.times { |i|
				x = rand(Graphics.width)
				y = rand(Graphics.height)
				set_xy_sprite("effect #{i} #{random1}", x, y)
				set_visible_sprite("effect #{i} #{random1}", true)
			}
			@trigger_effect[random1] = System.uptime
		end
	end

	#-------------------------------#
	# Features: perfect, good, miss #
	#-------------------------------#
	def update_features
		return if @checkall
		@showFeature.each { |k, v|
			arr = [:perfect, :good, :miss]
			arr.each_with_index { |name, i| v[name] = @result ? update_dispose_all_features(v[name], i, k) : update_small_features(v[name], i, k) }
		}
		@checkall = true if @result
	end

	def update_small_features(arr, feature, nameplayer)
		return [] if arr.size == 0
		arr2 = ["Perfect", "Good", "Miss"]
		name = feature == 0 ? :perfect : feature == 1 ? :good : :miss
		arr.each_with_index { |a, i|
			spritename = "#{arr2[feature]} #{@count[nameplayer][name]}"
			arr[i] -= 1
			arr[i]  = 0 if a < 0
			dispose(spritename) if a == 1
		}
		return arr
	end

	def update_dispose_all_features(arr, feature, nameplayer)
		return [] if arr.size == 0
		arr2 = ["Perfect", "Good", "Miss"]
		name = feature == 0 ? :perfect : feature == 1 ? :good : :miss
		arr.each_with_index { |a, i|
			spritename = "#{arr2[feature]} #{@count[nameplayer][name]}"
			dispose(spritename) if !@sprites[spritename].nil?
		}
	end

	#-------------#
	# Update time #
	#-------------#
	def update_time_bar(num)
		return if @result
		if @sprites["time bar"].x + num > 188
			@sprites["time bar"].x = 188
			# Store result
			set_order_result
			# Deaccelerate circle
			deaccelerate_circle
			# Fade
			fade_in
			@result = true
			return
		end
		@sprites["time bar"].x += num
	end

	def update_time_bar_auto = update_time_bar(0.5)

#== Input =================================================================================================================

	def set_input
		player_press
		press_AI_top_right
		press_AI_bottom_left
		press_AI_bottom_right
		press_AI_special
	end

	#-------------#
	# Player play #
	#-------------#
	def player_press
		@exit = true if checkInput(Input::BACK) && @showPage == 1
		return unless checkInput(Input::USE)
		if @result
			@showPage == 0 ? (@showPage = 1) : (@exit = true)
			return
		end
		angle = @sprites["circle"].angle
		angle = 40 if $DEBUG && Input.press?(Input::CTRL)
		angle = 30 if $DEBUG && Input.press?(:G)
		angle = 20 if $DEBUG && Input.press?(:M)
		if angle.between?(35,45)
			angle_circle(:perfect, 40)
		elsif angle.between?(25,55)
			angle_circle(:good, 40)
		else
			angle_circle(:miss, 40)
		end
	end

	#------------------------#
	# Set AI play, not input #
	#------------------------#
	def press_AI_normal(num, angle)
		return if @result
		return if @playerCount < num || @playerCount == 4
		return if !@sprites["circle"].angle.between?(angle - 5,angle + 5)
		return if @pressCheck[num]
		chance = rand(100)
		npc_accuracy = [
			[[25, :perfect, 75, :good], [33, :perfect, 67, :good], [11, :perfect, 89, :good]], # RPM < 27.46
			[[20, :perfect, 60, :good, 10, :miss]],	# RPM 27.46 - 82.39 (only for the NPC 1)
			[[10, :perfect, 20, :good, 30, :miss], 	# RPM >= 27.46
			 [35, :perfect, 25, :good, 10, :miss],
			 [40, :perfect,  5, :good,  5, :miss],
			], 
		]
		result = :ignore
		spd = 0
		if @current_rpm < 27.46
			spd = 0 
		elsif @current_rpm >= 82.39 && num == 1
			spd = 1
		else # rpm 27.46 - 82.39
			spd = 2
		end
		acc = npc_accuracy[spd][num - 1]
		total_precentage = 0
		(acc.length / 2).times do |i|
			next if result != :ignore
			if chance < acc[i * 2] + total_precentage
				result = acc[i * 2 + 1]
			end
			total_precentage += acc[i * 2]
		end
		# echoln "NPC #{num} : #{result}"
		angle_circle(result, angle, num) if result != :ignore
		@pressCheck[num] = true
	end

	def press_AI_top_right = press_AI_normal(1, 320)

	def press_AI_bottom_left = press_AI_normal(2, 140)

	def press_AI_bottom_right = press_AI_normal(3, 220)

	# Berry Master
	def press_AI_special
		return if @result
		return if @playerCount != 4
		angle = 320
		return if !@sprites["circle"].angle.between?(angle - 5,angle + 5)
		return if @pressCheck[1]
		# Berry master always do a perfect input
		angle_circle(:perfect, 320, 1)
		@pressCheck[1] = true
	end

	def reset_AI_input
		3.times do |i|
			@pressCheck[i+1] = false
		end
	end

	#------------------------------------------------------------------------------#
	# Set SE for input
	#------------------------------------------------------------------------------#
	def checkInput(name,exact=false)
		if exact
			if Input.triggerex?(name)
				(name==:X)? pbPlayCloseMenuSE : pbPlayDecisionSE
				return true
			end
		else
			if Input.trigger?(name)
				(name==Input::BACK)? pbPlayCloseMenuSE : pbPlayDecisionSE if @showPage != 0
				return true
			end
		end
		return false
	end
		
#== Result =================================================================================================================

	def set_order_result
		hash = {}
		@name.each_with_index { |name, i|
			arr1 = [name, @berry[i], []]
			arr2 = [:perfect, :good, :miss]
			sum  = 0
			arr2.each_with_index { |a, i|
				arr1[2] << @count[name][a]
				sum +=
					if i != 2
						10 ** (4 - i * 2) * @count[name][a]
					else
						- @count[name][a]
					end
			}
			hash[arr1] = sum
		}
		hash  = hash.sort_by(&:last).reverse.to_h
		num   = 0
		value = hash.values
		value.each_with_index { |v, i|
			num += 1
			if i == 0
				@orderNum << num
			else
				if value[i] == value[i-1]
					@orderNum[i] = @orderNum[i-1]
					num -= 1
				else
					@orderNum << num
				end
			end
		}
		@order = hash
		# Store in global
		store_in_global_result
	end

	def store_in_global_result
		sheen = BerryPoffin.averageSmoothness(@berry)
		if @berry.uniq.size != @berry.size || @forceFail
			# Black
			store_flavor_global_black(sheen)
		else
			flavor = []
			plus = false
			# Feel Calculation
			@berry.each { |berry| flavor << GameData::BerryData.get(berry).calculatedFlavor[1]}
			sum = [0, 0, 0, 0, 0]
			flavor.each { |fla|
				fla.each_with_index { |f, i| sum[i] += f }
			}
			negatives = 0
			sum.each do |x| negatives += 1 if x < 0 end
			sum.map! { |s| (s - negatives) } # each flavour substract by negative value counts
			sum.map! { |s| s <= 0 ? 0 : s }	 # set each negative value to 0
			# flavour multiplier = ([max rpm] / 333.0) + 1
			vitess = @maxSpeed == 110 ? 1.33 : (@maxSpeed / 333.0 + 1).truncate(2)
			sum.map! { |s| s * vitess }
			sum.map! { |s| s.round } # round up
			# Set global
			positive = sum.select { |s| s > 0 }
			level    = positive.max
			positionofmax = sum.index(level)
			flavorplus50  = sum.select { |s| s > 50 }.size > 0
			case positive.size
			when 0 then store_flavor_global_black(sheen)
			# 1 flavor
			when 1
				if flavorplus50
					name = "Gold"
				else
					arr  = ["Red", "Blue", "Pink", "Green", "Yellow"]
					name = arr[positionofmax]
				end
			# 2 flavors
			when 2
				if flavorplus50
					name = "Gold"
				else
					arr = ["Purple", "Indigo", "Brown", "Lite Blue", "Olive"]
					name = arr[positionofmax]
				end
			# Gray
			when 3 then name = "Gray"
			# White
			when 4, 5 then name = "White"
			end
			return if positive.size == 0
			newBlock = Pokeblock.new(name.to_sym,sum,sheen,plus)
			pbGainPokeblock(newBlock)
			# Set Result Display
			@flavorGet = [newBlock.color_name,newBlock.level,newBlock.smoothness]
		end
	end

	# Black flavor
	def store_flavor_global_black(sheen)
		arr  = []
		fake = []
		loop do
			random = rand(5)
			fake << random
			if fake.size == 3
				fake = [] if fake.uniq.size != fake.size
				break if fake.size == 3
			end
		end
		5.times { |i|
			if fake.include?(i)
				arr[i] = 2
				fake.delete(i)
			else
				arr << 0
			end
		}
		newBlock = Pokeblock.new(:Black,arr,sheen)
		pbGainPokeblock(newBlock)
		# Set Result Display
		@flavorGet = [newBlock.color_name,newBlock.level,newBlock.smoothness]
	end
	
end