class HackingGame_Scene

    class HackingPlayer < IconSprite
        attr_accessor :charged

        def initialize(*args)
            super(*args)
            @charged = false
            @charged_frame = 0
            self.setBitmap(_INTL("Graphics/UI/Hacking Game/player"))
        end

        def charged=(val)
            return unless val != @charged
            @charged = val
            if @charged
                @charged_frame = 0
                if @charged_overlay.nil?
                    @charged_overlay = IconSprite.new(self.x, self.y, self.viewport)
                    @charged_overlay.setBitmap("Graphics/UI/Hacking Game/player_charged")
                    @charged_overlay.z = self.z
                    @charged_overlay.visible = false
                end
            else
                @charged_overlay.visible = false
            end
        end

        def reset
            @charged = false
            @charged_overlay&.visible = false
			@interact_indicator&.visible = false
        end

		def show_interact
            if @interact_indicator.nil? && HackingGameSettings::SHOW_INTERACT_INDICATOR
				@interact_indicator = IconSprite.new(self.x, self.y - HackingGameSettings::GRID_SQUARE_SIZE, self.viewport)
				@interact_indicator.setBitmap("Graphics/UI/Hacking Game/player_interact")
				@interact_indicator.z = self.z
            end
			@interact_indicator&.visible = true
		end

		def hide_interact
			@interact_indicator&.visible = false
		end

        def x=(val)
            super
            @charged_overlay&.x = val
            @interact_indicator&.x = val
        end

        def y=(val)
            super
            @charged_overlay&.y = val
            @interact_indicator&.y = val - HackingGameSettings::GRID_SQUARE_SIZE
        end

        def update
            super
            if @charged
                @charged_frame += 1
                @charged_frame = 0 if @charged_frame >= 40
                @charged_overlay.visible = @charged_frame.between?(10, 14)
            end
        end

        def dispose
            super
            @charged_overlay&.dispose
            @interact_indicator&.dispose
        end
    end

    class HackingAntivirus < IconSprite
        attr_accessor :id
        attr_accessor :graphic_index
        attr_accessor :active
        attr_accessor :origin
        attr_accessor :speed
        attr_accessor :sight
        attr_accessor :moving_to

        def initialize(id, *args)
            super(*args)
            @id = id
            @graphic_index = 1 
            @active = false
            @speed = 1
            @sight = 2
            refresh_graphic
        end

        def activate
            return if @active
            @active = true
            return if @graphic_index == 0
            @graphic_index = 0
            refresh_graphic
        end

        def deactivate
            return if !@active
            @active = false
            return if @graphic_index == 1
            @graphic_index = 1
            refresh_graphic
        end

        def speed=(val)
            @speed = val
            refresh_graphic
        end

        def refresh_graphic
            graphic = _INTL("Graphics/UI/Hacking Game/antivirus")
            graphic_check = _INTL("Graphics/UI/Hacking Game/antivirus_speed_#{@speed}")
            graphic = graphic_check if pbResolveBitmap(graphic_check)
            self.setBitmap(graphic)
            size = HackingGameSettings::GRID_SQUARE_SIZE
            self.src_rect.set(size*@graphic_index, 0, size, size) if self.width > size
        end

        def pbTouchingPlayer?(player)
            return false unless self.visible
            return (player.x - self.x).abs < HackingGameSettings::GRID_SQUARE_SIZE / 2 &&
                (player.y - self.y).abs < HackingGameSettings::GRID_SQUARE_SIZE / 2
        end

        # def pbCanSeePlayer?(player)
        #     return false unless self.visible
        #     return (player.x - self.x).abs <= @sight * HackingGameSettings::GRID_SQUARE_SIZE &&
        #         (player.y - self.y).abs <= @sight * HackingGameSettings::GRID_SQUARE_SIZE
        # end
    end

    class HackingNode < IconSprite
        attr_accessor :type
        attr_accessor :graphic
        attr_accessor :graphic_index
        attr_accessor :coords
        attr_accessor :id
        attr_accessor :state
        attr_accessor :starting_state
        attr_accessor :grouped
        attr_accessor :puzzle
        attr_accessor :puzzle_key_count
        attr_accessor :puzzle_hidden
        attr_accessor :disabled_info
        attr_accessor :disabled_unlocked
        attr_accessor :hide_when_disabled
        attr_accessor :keys_to_reveal
        attr_accessor :charge_target

        def inspect
            str = super.chop
            str << sprintf(" %s %s>", @type, self.visible.to_s)
            return str
        end

        def initialize(type, coords, *args)
            super(*args)
            @type = type
            @coords = [*coords]
            data = HackingGameSettings::NODE_INFO[@type]
            @graphic = data[:graphic]
            @graphic_index = data[:graphic_index] || 0
            @grouped = data[:needs_group]
            @state = data[:start_state] || 0 # 0 is unlocked, 1 is locked 
            refresh
        end

        def get_data
            return HackingGameSettings::NODE_INFO[@type]
        end

        def get_name
            name = HackingGameSettings::NODE_INFO[@type][:name] || "Undefined"
            if @id
                name += _INTL(" Group") if @grouped
                name += " #{@id}"
            end
            return name
        end

        def can_interact?
			return false if type == :Base
            return false if @disabled_overlay&.visible
            return true if !@disabled_info 
            return @disabled_unlocked
            return self.visible && @state == 0
        end

        def linked_to?(node)
            return get_data[:linked_type] && get_data[:linked_type] == node.type && @id == node.id
        end

        def unlock
            @state = 0
            @graphic_index = 1
            refresh
        end

        def state=(val)
            @state = val
            @graphic_index = 1 if @state == 0
            @graphic_index = 0 if @state == 1
        end

        def toggle_disabled_graphic(val, editing = false)
            if val && @disabled_overlay.nil?
                if !editing && @hide_when_disabled
                    self.visible = false
                else
                    @disabled_overlay = IconSprite.new(self.x, self.y, self.viewport)
                    @disabled_overlay.setBitmap("Graphics/UI/Hacking Game/node_disabled" + (editing ? "_editview" : ""))
                    @disabled_overlay.z = self.z
                end
            elsif !val
                @disabled_overlay&.dispose
                @disabled_overlay = nil
                self.visible = true
            end
        end

        def refresh
            self.setBitmap(@graphic)
            size = HackingGameSettings::GRID_SQUARE_SIZE
            self.src_rect.set(size*@graphic_index, 0, size, size) if self.width > size
            self.visible = false if @hide_when_disabled && !@disabled_unlocked
            self.update
        end

        def dispose
            super
            @disabled_overlay&.dispose
        end

    end

    class HackingPath < IconSprite
        attr_accessor :type
        attr_accessor :dir
        attr_accessor :state
        attr_accessor :starting_state
        attr_accessor :graphic
        attr_accessor :graphic_index
        attr_accessor :coords_a
        attr_accessor :coords_b
        attr_accessor :linked_type
        attr_accessor :id

        def initialize(type, dir, coords_a, coords_b, *args)
            super(*args)
            @type = type
            @dir = dir # 0 = Vertical, 1 = Horizontal
            @coords_a = [*coords_a] # Left, Top
            @coords_b = [*coords_b] # Right, Bottom
            data = HackingGameSettings::PATH_INFO[@type]
            @graphic = data[:graphic]
            @linked_type = data[:linked_type]
            @graphic_index = @dir
            @state = data[:start_state] || 0 # 0 is unlocked, 1 is locked
            # @starting_state = @state
            self.setBitmap(@graphic)
            size = HackingGameSettings::GRID_SQUARE_SIZE
            self.src_rect.set(size*@graphic_index, 0, size, size) if self.width > size
        end

        def state=(val)
            @state = val # 0 is unlocked, 1 is locked
            @state = 0 if @state.nil?
            self.visible = @state == 0
        end

        def get_data
            return HackingGameSettings::PATH_INFO[@type]
        end

        def get_name
            name = HackingGameSettings::PATH_INFO[@type][:name] || "Undefined"
            name += " (Concealed)" if HackingGameSettings::PATH_INFO[@type][:dual_state] && @state == 1
            name += " Linked to #{@id}" if @id
            return name
        end

        def show_editview
            self.setBitmap(@graphic + "_editview")
            size = HackingGameSettings::GRID_SQUARE_SIZE
            self.src_rect.set(size*@graphic_index, 0, size, size) if self.width > size
            self.visible = true
        end

        def can_pass
            return self.visible && @state == 0
        end

        def linked_to?(node)
            return @linked_type && @linked_type == node.type && @id == node.id
        end

    end

    class HackingKey < IconSprite
        attr_accessor :dir
        attr_accessor :graphic
        attr_accessor :state # 0 => default, 1 => current, 2 => correct, 3 => guessed, 4 => wrong
        attr_accessor :hidden

        def initialize(dir, state, hidden, *args)
            super(*args)
            @dir = dir
            @state = state
            @hidden = hidden
            data = HackingGameSettings::NODE_INFO[@type]
            if @hidden
                @graphic = _INTL("Graphics/UI/Hacking Game/key_hidden")
            else
                key = ["up", "down", "left", "right"][[8, 2, 4, 6].index(@dir)]
                @graphic = _INTL("Graphics/UI/Hacking Game/key_{1}", key)
            end
            self.setBitmap(@graphic)
            size = self.height
            self.src_rect.set(size*@state, 0, size, size)
            self.z = 75
        end

        def reveal_dir(val)
            return unless @hidden
            @dir = val 
            key = ["up", "down", "left", "right"][[8, 2, 4, 6].index(@dir)]
            @graphic = _INTL("Graphics/UI/Hacking Game/key_{1}", key)
            self.setBitmap(@graphic)
            size = self.height
            self.src_rect.set(size*@state, 0, size, size)
        end

        def hidden=(val)
            return if @hidden == val
            @hidden = val
            if @hidden
                @graphic = _INTL("Graphics/UI/Hacking Game/key_hidden")
            else
                key = ["up", "down", "left", "right"][[8, 2, 4, 6].index(@dir)]
                @graphic = _INTL("Graphics/UI/Hacking Game/key_{1}", key)
            end
            self.setBitmap(@graphic)
            size = self.height
            self.src_rect.set(size*@state, 0, size, size)
        end

        def state=(val)
            @state = val
            @state = 0 if @state.nil?
            size = self.height
            self.src_rect.set(size*@state, 0, size, size)
        end

    end
end