#===============================================================================
# Simple Berry Blender Scene
#===============================================================================
class SimpleBerryBlender_Scene < BerryBlender_Scene
	include BopModule

	def pbStartScene
		# Viewport
		@viewport = Viewport.new(0,0,Graphics.width,Graphics.height)
		@viewport.z = 99999
		# Values
		# Set number to define player, quantity of players
		@playerCount = 0
		reset_parameter
	end
	
	def reset_parameter(restarted = false)
		@restarted = restarted if restarted
		@sprites = {}
		# Store berry
		@berry = []
		# Set speed of circle
		@current_rpm = 400 # Magic Number
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
	end
	
	#--------------#
	# Create scene #
	#--------------#
	def create_scene
		# Create scene
		create_sprite("behind", "SimpleBackground", @viewport)
		create_sprite("scene", "Simple", @viewport)
		# Create circle
		create_sprite("circle", "CircleSimple", @viewport)
		ox = @sprites["circle"].bitmap.width / 2
		oy = @sprites["circle"].bitmap.height / 2
		set_oxoy_sprite("circle", ox, oy)
		x = Graphics.width / 2
		y = Graphics.height / 2
		set_xy_sprite("circle", x, y)
		set_zoom_sprite("circle", 3, 3)
		set_visible_sprite("circle")
	end
	
	def pbScene
		# Create
		create_scene
		# Fade
		pbFadeInAndShow(@sprites) { update } if !@restarted
		# Choose berry
		notplay = false
		@berries   = nil
		if @restarted then @restarted = nil;
		else
			pbMessage(_INTL("Starting up the Berry Blender...")) 
			pbMessage(_INTL("Please select some berries from your bag to put in the Berry Blender."))
		end
		loop do
			@berries = BerryPoffin.pbPickBerryForBlenderSimple
			break notplay = true if @berries.nil? || @berries.empty?
			break
		end
		return if notplay
		# Animation berry
		animationBerry(@berries)
		# Zoom
		zoom_circle_before_start
		# Fade
		fade_out
		# Blender Animation
		accelerate_circle
		circle_animation
		deaccelerate_circle
		@exit = true
		@relust = true
		# Result
		results = pbCalculateSimplePokeblock(@berries)
		results.each { |pb| pbGainPokeblock(pb) }
		pbMessage(_INTL("You created {1} {2} Pokéblocks{3}!",results.length,results[0].color_name,(results[0].plus ? " +" : "")))
		return true if $bag.hasAnyBerry? && pbConfirmMessage(_INTL("Would you like to blend more berries?"))
		return false
	end

#=== Pokeblock Calculation ==========================================================================================

	def pbCalculateSimplePokeblock(berries)
		probability = 0
		posColors = []
		@berries.each { |berry| 
			data = GameData::BerryData.get(berry.id)
			probability += data.plusProbability
			posColors.push(data.block_color)
		}
		color = nil
		uniqColors = posColors.uniq
		if uniqColors.length >=4 then color = :Rainbow;
		elsif uniqColors.length == 1 then color = uniqColors[0]; 
		elsif uniqColors.length == posColors.length then color = posColors.sample;
		else
			c = []
			uniqColors.each { |color| 
				next c.push(color) if c.empty? || posColors.count(color) == posColors.count(c[0])
				c[0] = color if posColors.count(color) > posColors.count(c[0])
			}
			color = c.sample
		end
		plus = rand(100)<probability
		flavor = [0,0,0,0,0]
		fVal = (plus ? 15 : 5 )
		case color
		when :Rainbow then flavor = [fVal,fVal,fVal,fVal,fVal]
		when :Red then flavor[0] = fVal
		when :Blue then flavor[1] = fVal
		when :Pink then flavor[2] = fVal
		when :Green then flavor[3] = fVal
		when :Yellow then flavor[4] = fVal
		end
		results = []
		qty = berries.length
		qty.times { results.push(Pokeblock.new(color,flavor,0,plus)) }	
		return results
	end

#=== Animations ====================================================================================================================

	#-------------#
	# Turn circle #
	#-------------#
	def circle_animation
		timer = System.uptime
		loop do
			update_ingame
			angle = (@current_rpm * 360) / (60.0 * Graphics.frame_rate)
			# Update circle sprite
			@sprites["circle"].angle += angle
			@sprites["circle"].angle %= 360
			break if System.uptime - timer > 3 # 3 seconds
		end		
	end

	def accelerate_circle
		duration = 1
		target_rpm = @current_rpm
		timer = System.uptime
		loop do
			update_ingame
			current_rpm = lerp(0, target_rpm, duration, timer, System.uptime)
			angle = (current_rpm * 360) / (60.0 * Graphics.frame_rate)
			# Update circle sprite
			@sprites["circle"].angle += angle
			@sprites["circle"].angle %= 360
			break if current_rpm == target_rpm
		end
	end

	#-----------------#
	# Berry Animation #
	#-----------------#
	
	def animationBerry(berries)
		b=[true,true,true,true]; x0=[]; y0=[]; d=[rand(10),rand(10),rand(10),rand(10)]
		berries.each_with_index { |berry,pos|
			if !@sprites["berry #{pos}"]
				begin
					filename = GameData::Item.icon_filename(berry)
				rescue 
					p "You have an error when choosing berry"
					Kernel.exit!
				end
				@sprites["berry #{pos}"] = Sprite.new(@viewport)
				@sprites["berry #{pos}"].bitmap = Bitmap.new(filename)
				@sprites["berry #{pos}"].visible = false
				ox = @sprites["berry #{pos}"].bitmap.width/2
				oy = @sprites["berry #{pos}"].bitmap.height/2
				set_oxoy_sprite("berry #{pos}",ox,oy)
				x = Graphics.width / 2 + (pos==0 || pos==2 ? -Graphics.height/2 : Graphics.height/2)
				y = pos==0 || pos==1 ? 0 : Graphics.height
				set_xy_sprite("berry #{pos}",x,y)
				b[pos]=false
				x0[pos] = x
				y0[pos] = y
			end
		}
		t = time = 0
		loop do
			Graphics.update
			update
			r = Graphics.height/4*Math.sqrt(2)
			t += 0.05
			time += 1
			cos = Math.cos(t)
			sin = Math.sin(t)
			if @sprites["berry 0"] && !b[0] && time>d[0]
				@sprites["berry 0"].visible = true
				@sprites["berry 0"].x =  r*(1-cos) + x0[0]
				@sprites["berry 0"].y =  r*(t-sin) + y0[0]
				if @sprites["berry 0"].y >= (Graphics.height/2-10)
					b[0] = true; @sprites["berry 0"].visible = false; end
			end
			if @sprites["berry 1"] && !b[1] && time>d[1]
				@sprites["berry 1"].visible = true
				@sprites["berry 1"].x = -r*(1-cos) + x0[1]
				@sprites["berry 1"].y =  r*(t-sin) + y0[1]
				if @sprites["berry 1"].y >= (Graphics.height/2-10)
					b[1] = true; @sprites["berry 1"].visible = false; end
			end
			if @sprites["berry 2"] && !b[2] && time>d[2]
				@sprites["berry 2"].visible = true
				@sprites["berry 2"].x =  r*(t-sin) + x0[2]
				@sprites["berry 2"].y = -r*(1-cos) + y0[2]
				if @sprites["berry 2"].y <= (Graphics.height/2+10)
					b[2] = true; @sprites["berry 2"].visible = false; end
			end
			if @sprites["berry 3"] && !b[3] && time>d[3]
				@sprites["berry 3"].visible = true
				@sprites["berry 3"].x = -r*(t-sin) + x0[3]
				@sprites["berry 3"].y = -r*(1-cos) + y0[3]
				if @sprites["berry 3"].y <= (Graphics.height/2+10)
					b[3] = true; @sprites["berry 3"].visible = false; end
			end
			break if (b[0]&&b[1]&&b[2]&&b[3])
		end
		dispose("berry 0"); dispose("berry 1"); dispose("berry 2"); dispose("berry 3");
	end	
end