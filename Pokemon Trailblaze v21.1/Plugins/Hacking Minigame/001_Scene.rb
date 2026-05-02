def pbHackingGame(id = nil, can_quit = true, start_messages = nil, win_messages = nil)
	if id.nil? && !$DEBUG
		pbMessage(_INTL("pbHackingGame was called without a game ID."))
		return false
	end
    ret = nil
    pbFadeOutInWithMusic {
        scene = HackingGame_Scene.new(id, can_quit, start_messages, win_messages)
        screen = HackingGame_Screen.new(scene)
        ret = screen.pbStartScreen
    }
    return ret
end

#===============================================================================
# Scene
#===============================================================================  
class HackingGame_Screen
    def initialize(scene)
        @scene = scene
    end
  
    def pbStartScreen
        ret = @scene.pbStartScene
        return false if ret == false
        ret = @scene.pbScene
        @scene.pbEndScene
        return ret
    end
end
  
class HackingGame_Scene
    def initialize(id = nil, can_quit = true, start_messages = nil, win_messages = nil)
        @game_id = id
        @can_quit = can_quit
        @start_messages = (start_messages.is_a?(String) ? [start_messages] : start_messages) if @game_id
        @win_messages = (win_messages.is_a?(String) ? [win_messages] : win_messages) if @game_id
    end

    def pbStartScene
        $hacking = self if $DEBUG # Quick and dirty access to hacking scene for debugging
        if @game_id
            available = pbGetAvailableGames[@game_id]
            if !available
                raise _INTL("Hacking Game #{@game_id} does not exist.")
                return false
            elsif !available[:completed_playtest]
                pbMessage(_INTL("Hacking Game :#{@game_id} has not had a successful playtest."))
                pbMessage(_INTL("A successful playtest must be done in development."))
                return false
            end
        end
        @viewport = Viewport.new(0,0,Graphics.width,Graphics.height)
        @viewport.z = 99999
        @paths = {}
        @nodes = {}
        @antivirus = {}
        @sprites = {}
        @sprites["background"] = IconSprite.new(0, 0, @viewport)
        @sprites["background"].setBitmap(_INTL("Graphics/UI/Hacking Game/bg"))
        @sprites["background"].z = 1
        @sprites["edit_grid"] = IconSprite.new(0, 0, @viewport)
        @sprites["edit_grid"].setBitmap(_INTL("Graphics/UI/Hacking Game/grid_editview"))
        @sprites["edit_grid"].z = 2
        @sprites["edit_grid"].visible = false
        @sprites["overlay_charge"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
        @sprites["overlay_charge"].z = 3
        @sprites["cursor"] = IconSprite.new(0, 0, @viewport)
        @sprites["cursor"].setBitmap(_INTL("Graphics/UI/Hacking Game/cursor"))
        @sprites["cursor"].z = 5
        @sprites["cursor"].visible = false
        #@sprites["player"] = IconSprite.new(0, 0, @viewport)
        #@sprites["player"].setBitmap(_INTL("Graphics/UI/Hacking Game/player"))
        @sprites["player"] = HackingPlayer.new(0, 0, @viewport)
        @sprites["player"].z = 5
        @sprites["player"].visible = false
        @sprites["fog"] = IconSprite.new(0, 0, @viewport)
        @sprites["fog"].setBitmap(_INTL("Graphics/UI/Hacking Game/fog"))
        @sprites["fog"].z = 25
        @sprites["fog"].visible = false
        @sprites["puzzle_underlay"] = IconSprite.new(0, 0, @viewport)
        @sprites["puzzle_underlay"].bitmap = Bitmap.new(Graphics.width, Graphics.height)
        @sprites["puzzle_underlay"].bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0, 150))
        @sprites["puzzle_underlay"].z = 48
        @sprites["puzzle_underlay"].visible = false
        @sprites["puzzle_underlay_title"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
        @sprites["puzzle_underlay_title"].z = 49
        pbSetSystemFont(@sprites["puzzle_underlay_title"].bitmap)
        @sprites["frame"] = IconSprite.new(0, 0, @viewport)
        @sprites["frame"].setBitmap(_INTL("Graphics/UI/Hacking Game/bg_frame"))
        @sprites["frame"].z = 50
        @sprites["timer_bg"] = IconSprite.new(0, 0, @viewport)
        @sprites["timer_bg"].setBitmap(_INTL("Graphics/UI/Hacking Game/timer_bg"))
        @sprites["timer_bg"].z = 51
        @sprites["timer_bg"].x = (Graphics.width - @sprites["timer_bg"].width) / 2
        @sprites["timer_bg"].y = ((30 - @sprites["timer_bg"].height) / 4 ) * 2
        @sprites["timer_bg"].visible = false
        @sprites["timer_bar"] = IconSprite.new(@sprites["timer_bg"].x + 2, @sprites["timer_bg"].y + 2, @viewport)
        @sprites["timer_bar"].setBitmap(_INTL("Graphics/UI/Hacking Game/timer_bar"))
        @sprites["timer_bar"].z = 52
        @sprites["timer_bar"].visible = false
        @sprites["overlay_top"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
        @sprites["overlay_top"].z = 60
        pbSetSystemFont(@sprites["overlay_top"].bitmap)
        @sprites["overlay_side"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
        @sprites["overlay_side"].z = 60
        pbSetSystemFont(@sprites["overlay_side"].bitmap)
        @sprites["overlay_bottom"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
        @sprites["overlay_bottom"].z = 60
        pbSetSystemFont(@sprites["overlay_bottom"].bitmap)
        @sprites["puzzle_cursor"] = IconSprite.new(0, 0, @viewport)
        @sprites["puzzle_cursor"].setBitmap(_INTL("Graphics/UI/Hacking Game/key_cursor"))
        @sprites["puzzle_cursor"].z = 75
        @sprites["puzzle_cursor"].visible = false
        @sprites["helpwindow"] = Window_UnformattedTextPokemon.new("")
        @sprites["helpwindow"].visible  = false
        @sprites["helpwindow"].viewport = @viewport
        @sprites["helpwindow"].z = 100
        pbFadeInAndShow(@sprites) { pbUpdate }
    end
    
    def pbScene
        @games = pbGetAvailableGames
        @width = (Graphics.width / HackingGameSettings::GRID_SQUARE_SIZE) - 3
        @height = (Graphics.height / HackingGameSettings::GRID_SQUARE_SIZE) - 3
        if @game_id
            result = pbScenePlay
            return result
        else
            old_choice = 0
            loop do
                cmdPlay = -1
                cmdEdit = -1
                cmdImport = -1
                cmdExport = -1
                cmdCancel = -1
                commands = []
                commands[cmdPlay = commands.length] = _INTL("Play Game")
                commands[cmdEdit = commands.length] = _INTL("Game Editor")
                commands[cmdImport = commands.length] = _INTL("Import Game")
                commands[cmdExport = commands.length] = _INTL("Export Game")
                commands[cmdCancel = commands.length] = _INTL("Exit")
                cmd = pbShowCommands(_INTL("Select a mode."), commands, old_choice)
                old_choice = cmd
                if cmdPlay >= 0 && cmd == cmdPlay
                    game = pbChooseGame(nil, true)
                    result = pbScenePlay(game) if game
                    if result && @games[game] && !@games[game][:completed_playtest]
                        pbSavePlaytest(game)
                        @games = pbGetAvailableGames
                    end
                elsif cmdEdit >= 0 && cmd == cmdEdit
                    commands_e = [_INTL("Create Game"), _INTL("Edit Game"),_INTL("Delete Game"),_INTL("Cancel")]
                    cmd_e = pbShowCommands(_INTL("Game Editor"), commands_e)
                    case cmd_e
                    when 0
                        pbSceneEdit
                    when 1
                        game = pbChooseGame(_INTL("Edit which game?"))
                        pbSceneEdit(game) if game
                    when 2
                        game = pbChooseGame(_INTL("Delete which game?"))
                        if game 
                            name = @games[game][:name]
                            if pbConfirmMessageSerious(_INTL("Are you sure you want to delete {1}?", name))
                                pbDeleteGame(game)
                                @games = pbGetAvailableGames
                                pbMessage(_INTL("{1} was successfully deleted.", name))
                            end
                        end
                    end
                elsif cmdImport >= 0 && cmd == cmdImport
                    data = pbImportGameFromFile
                    if data
                        if @games[data[:id]]
                            commands_e = [_INTL("Overwrite it"), _INTL("Rename new game"),_INTL("Cancel import")]
                            cmd_e = pbShowCommands(_INTL("A game already exists with the same name or ID."), commands_e)
                            case cmd_e
                            when 0
                                data[:imported] = true
                                data[:completed_playtest] = false
                                pbSaveGame(data[:id], data)
                                @games = pbGetAvailableGames
                                pbMessage(_INTL("{1} was successfully imported!", @games[data[:id]][:name]))
                            when 1
                                name = data[:name]
                                loop do
                                    ret = pbMessageFreeText(_INTL("Enter the name of this game.\\nGame ID will be name without spaces."), name, false, HackingGameSettings::GAME_NAME_LIMIT || 20)
                                    if ret.empty?
                                        pbMessage(_INTL("The name cannot be blank."))
                                        next
                                    elsif ret == data[:name]
                                        pbMessage(_INTL("The name cannot be the same."))
                                        next
                                    end
                                    name = ret
                                    break
                                end
                                data[:name] = name.strip
                                data[:id] = name.gsub(/[^a-zA-Z0-9_]/, "").to_sym
                                data[:imported] = true
                                data[:completed_playtest] = false
                                pbSaveGame(data[:id], data)
                                @games = pbGetAvailableGames
                                pbMessage(_INTL("{1} was successfully imported!", @games[data[:id]][:name]))
                            end
                        else
                            data[:completed_playtest] = false
                            pbSaveGame(data[:id], data)
                            @games = pbGetAvailableGames
                            pbMessage(_INTL("{1} was successfully imported!", @games[data[:id]][:name]))
                        end
                    end
                elsif cmdExport >= 0 && cmd == cmdExport
                    game = pbChooseGame
                    pbExportGameToFile(game) if game
                elsif cmd < 0 || (cmdCancel >= 0 && cmd == cmdCancel)
                    break
                end
            end
        end
        return nil
    end

    def pbScenePlay(game_id = nil)
        @game_id = game_id if game_id
        pbLoadGame(@game_id)
        @coords = [*@game_info[:starting_position]]
        @timer = @game_info[:timer]
        @timer = nil if @timer && @timer <= 0
        @move_limit = @game_info[:move_limit]
        @move_limit = nil if @move_limit && @move_limit <= 0
        @move_count = 0
		@lives = @game_info[:max_lives]
		bgm = pbResolveAudioFile(@game_info[:bgm]) ? @game_info[:bgm] : HackingGameSettings::DEFAULT_BGM
		pbBGMPlay(bgm)
        if @timer
            if [1, 3].include?(HackingGameSettings::TIMER_TYPE)
                @sprites["timer_bar"].setBitmap(_INTL("Graphics/UI/Hacking Game/timer_bar"))
                @timer_start_width = @sprites["timer_bar"].width
                @timer_bar_height = @sprites["timer_bar"].height / 3
                @sprites["timer_bar"].src_rect.set(0, 0, @sprites["timer_bar"].width, @timer_bar_height)
                @timer_half_passed = false
                @timer_fourth_passed = false
            end
            if Essentials::VERSION.include?("20")
                @timer = @timer * Graphics.frame_rate
                @timer_start = @timer
                @timer_inc_per_frame = @sprites["timer_bar"].width.to_f / @timer
            else
                @timer_start = $stats.play_time
                @timer_start_width = @sprites["timer_bar"].width
            end
            if [2, 3].include?(HackingGameSettings::TIMER_TYPE)
                if Essentials::VERSION.include?("20")
                    curtime = [@timer / Graphics.frame_rate, 0].max
                else
                    curtime = [@timer - $stats.play_time + @timer_start].max
                end
                min = curtime / 60
                sec = curtime % 60
                text = _ISPRINTF("{1:02d}:{2:02d}", min, sec)
                @sprites["overlay_top"].bitmap.clear
                pbDrawTextPositions(@sprites["overlay_top"].bitmap,[[text, Graphics.width / 2, 4, 2, *HackingGameSettings::BORDER_TEXT_COLORS]])
            end
            pbToggleTimer(true)
        end
        if @move_limit
            @sprites["overlay_bottom"].bitmap.clear
            pbDrawTextPositions(@sprites["overlay_bottom"].bitmap, [[_INTL("Moves Remaining: {1}", @move_limit - @move_count), 
                    Graphics.width / 2, Graphics.height - 24, 2, *HackingGameSettings::BORDER_TEXT_COLORS]])
        end
		pbDrawSidePanel if @lives && @lives > 0
        if !@game_info[:fog].nil?
            b = _INTL("Graphics/UI/Hacking Game/fog")
            b = HackingGameSettings::FOG_OF_WAR_SIZES[@game_info[:fog]][1] if HackingGameSettings::FOG_OF_WAR_SIZES[@game_info[:fog]] 
            @sprites["fog"].setBitmap(b)
            @sprites["fog"].visible = true
        end
        if pbGameHasNodesOfType?(:Charge)
            pbDrawChargeWires
            pbCheckChargeWireDisables
        end
        @game_result = nil
        update_cursor(true)
        @sprites["player"].reset
        @sprites["player"].visible = true
        #pbMessage(_INTL("Play game!"))

        if @start_messages
			@start_messages.each { |s| pbMessage(s + "\1")} 
		else
			message = HackingGameSettings::DEFAULT_START_MESSAGE
			if message.nil? || message == ""
			elsif message.is_a?(Array)
				message.each { |s| pbMessage(s + "\1")}
			else
				pbMessage(message)
			end
        end

        loop do
            Graphics.update
            Input.update
            pbUpdate
            quit = false
			if @restarting
				15.times { Graphics.update }
				@restarting = nil
				@coords = [*@game_info[:starting_position]]
                @antivirus.each do |key, a|
                    a.x, a.y = convert_coords(a.origin)
                    a.deactivate
                    a.visible = true
                end
                @sprites["frame"].setBitmap(_INTL("Graphics/UI/Hacking Game/bg_frame"))
                @nodes.each do |key, node|
                    next if node.nil?
                    next if node.type != :Charge
                    node.state = node.starting_state
                    node.refresh
                end
                @paths.each do |key, path|
                    next if path.nil?
                    next if path.type != :Swap
                    path.state = path.starting_state if path.starting_state
                end
				update_cursor(true)
			end
            @old_coords = [*@coords]
            if @timer && @timer <= 0
                pbMessage(_INTL("Time's up!"))
                @game_result = false
                break
            end
            if @move_limit && @move_limit - @move_count <= 0
                pbMessage(_INTL("Out of moves!"))
                @game_result = false
                break
            end
            if Input.trigger?(Input::USE)
                pbPlayCurrentNode(true)
            elsif Input.trigger?(Input::BACK) && @can_quit
                #if pbConfirmMessage(_INTL("Give up?")) {pbUpdate}
                if 0 == pbShowCommands(_INTL("Give up?"), [_INTL("Yes"), _INTL("No")]) { pbUpdate }
                    pbPlayCancelSE
                    @game_result = false
                    break
                end
            elsif Input.repeat?(Input::LEFT)
                if @coords[0] == 0 || !pbCanMove(4)
                    pbPlayBuzzerSE
                else
                    @coords[0] -= 1
                    pbPlayCursorSE
                end
            elsif Input.repeat?(Input::RIGHT)
                if @coords[0] == @width || !pbCanMove(6)
                    pbPlayBuzzerSE
                else
                    @coords[0] += 1
                    pbPlayCursorSE
                end
            elsif Input.repeat?(Input::UP)
                if @coords[1] == 0 || !pbCanMove(8)
                    pbPlayBuzzerSE
                else
                    @coords[1] -= 1
                    pbPlayCursorSE
                end
            elsif Input.repeat?(Input::DOWN)
                if @coords[1] == @height || !pbCanMove(2)
                    pbPlayBuzzerSE
                else
                    @coords[1] += 1
                    pbPlayCursorSE
                end
            end
            if @coords != @old_coords
                @old_coords = [*@coords]
                @move_count += 1
                update_cursor
                if @move_limit
                    @sprites["overlay_bottom"].bitmap.clear
                    pbDrawTextPositions(@sprites["overlay_bottom"].bitmap, [[_INTL("Moves Remaining: {1}", @move_limit - @move_count), 
                            Graphics.width / 2, Graphics.height - 24, 2, *HackingGameSettings::BORDER_TEXT_COLORS]])
                end
            end
            #if @game_result
            if !@game_result.nil?
                break
            end
        end
        @paths.each { |path| path[1] && path[1].dispose}
        @nodes.each { |node| node[1] && node[1].dispose}
        @antivirus.each { |a| a[1] && a[1].dispose}
        @paths = {}
        @nodes = {}
        @antivirus = {}
        @sprites["player"].reset
        @sprites["player"].visible = false
        @sprites["fog"]&.visible = false
        pbToggleTimer(false)
        @timer = nil
        @sprites["overlay_charge"].bitmap.clear
        @sprites["overlay_top"].bitmap.clear
		@sprites["overlay_side"].bitmap.clear
        @sprites["overlay_bottom"].bitmap.clear
        @sprites["frame"].setBitmap(_INTL("Graphics/UI/Hacking Game/bg_frame"))
        return @game_result
    end

    def pbPlayCurrentNode(input_trigger = false)
        node = @nodes[[*@coords]]
        data = node.get_data
        if node.type == :Finish && node.can_interact?
            return pbWin
        elsif data[:no_puzzle] && ![:Key, :Charge].include?(node.type)
            return nil
        elsif node.can_interact? && (input_trigger || !HackingGameSettings::MUST_PRESS_BUTTON_TO_START_PUZZLES)
            pbRunNode(node)
        end

    end

    def pbRunNode(node)
        case node.type
        when :Locked
            if node.state == 1
                ret = pbPlayPuzzle(node)
                pbUnlockNode(node) if ret
            end
        when :Checkpoint
            if node.state == 1
                ret = pbPlayPuzzle(node)
                pbUnlockNode(node) if ret
            end
        when :Light
            if node.state == 1
                ret = pbPlayPuzzle(node)
                pbUnlockNode(node) if ret
            end
        when :Swap
            ret = pbPlayPuzzle(node)
            if ret
                @paths.each do |key, path|
                    next if path.nil?
                    next unless path.linked_to?(node)
                    path.state = (path.state == 0 ? 1 : 0)
                end
            end
        when :Key
            pbRevealKeys(node)
        when :Charge
            if node.state == 0 && @sprites["player"].charged # Drained
                @sprites["player"].charged = false
                node.state = 1
                node.refresh
                pbDrawSidePanel
                pbCheckChargeWireDisables
            elsif node.state == 1 && !@sprites["player"].charged
                @sprites["player"].charged = true
                node.state = 0
                node.refresh
                pbDrawSidePanel
                pbCheckChargeWireDisables
            end
        end
    end

    def pbUnlockNode(node)
        node.unlock
        if node.type == :Light
            if !@nodes.any? {|n| n[1] && n[1].type == node.type && n[1].state != 0}
                @sprites["fog"]&.visible = false
                @paths.each do |key, path|
                    next if path.nil?
                    next unless path.get_data[:linked_type] == node.type
                    path.state = 0
                end
                @nodes.each do |key, node_n|
                    next if node_n.nil?
                    next unless node_n.disabled_info
                    next if node_n.disabled_info[:type] != node.type
                    node_n.disabled_unlocked = true
                    node_n.toggle_disabled_graphic(false)
                end
            end
        elsif node.get_data[:needs_group]
            if !@nodes.any? {|n| n[1] && n[1].type == node.type && n[1].id == node.id && n[1].state != 0}
                @paths.each do |key, path|
                    next if path.nil?
                    next unless path.linked_to?(node)
                    path.state = 0
                end
                @nodes.each do |key, node_n|
                    next if node_n.nil?
                    next unless node_n.disabled_info
                    next if node_n.disabled_info[:type] != node.type
                    next if node_n.disabled_info[:id] != node.id
                    node_n.disabled_unlocked = true
                    node_n.toggle_disabled_graphic(false)
                end
            end
        else
            @paths.each do |key, path|
                next if path.nil?
                next unless path.linked_to?(node)
                path.state = 0
            end
            @nodes.each do |key, node_n|
                next if node_n.nil?
                next unless node_n.disabled_info
                next if node_n.disabled_info[:type] != node.type
                next if node_n.disabled_info[:id] != node.id
                node_n.disabled_unlocked = true
                node_n.toggle_disabled_graphic(false)
            end
        end
        pbCheckChargeWireDisables if pbGameHasNodesOfType?(:Charge)
    end

    def pbPlayPuzzle(node = nil)
        index = 0
        node = @sprites["node_#{[*@coords]}"] if node.nil?
        puzzle = node.puzzle
        count = node.puzzle_key_count
        hidden = node.puzzle_hidden
        if puzzle.nil?
            mean = (HackingGameSettings::PUZZLE_KEY_LIMIT / 2).round
            stddev = 1.0
            count = mean + stddev * (Math.sqrt(-2 * Math.log(1 - rand))) * Math.cos(2 * Math::PI * rand)
            count = count.round.clamp(1, HackingGameSettings::PUZZLE_KEY_LIMIT)
            node.puzzle = puzzle
            node.puzzle_key_count = count
            puzzle = []
            count.times { puzzle.push([2, 4, 6, 8].sample) }
            node.puzzle = puzzle
            node.puzzle_key_count = count
        elsif puzzle == :Random
            puzzle = []
            count.times { puzzle.push([2, 4, 6, 8].sample) }
        end
        key_sprites = []
        puzzle.each_with_index do |key, i|
            x = 8 + (Graphics.width - 64) / 2 - 32 * (puzzle.length - 1) + 64 * i
            y = (Graphics.height - 64) / 2
            state = i == index ? 1 : 0 # 0 => default, 1 => current, 2 => correct, 3 => guessed, 4 => wrong
            hide = false
            hide = true if hidden == true || (hidden.is_a?(Array) && hidden[i])
            key_sprites[i] = HackingKey.new(key, state, hide, x, y, @viewport)
        end
        @sprites["puzzle_cursor"].x = key_sprites[index].x - 8
        @sprites["puzzle_cursor"].y = key_sprites[index].y - 8
        @sprites["puzzle_cursor"].visible = true
        @sprites["puzzle_underlay"].visible = true
        result = nil
        wait_timer = 0
        loop do
            Graphics.update
            Input.update
            pbUpdate
            quit = false
            old_index = index
            if @restarting
                result = false
                break
            end
            if wait_timer > 0
                wait_timer -= 1
                break if wait_timer <= 0
            elsif Input.trigger?(Input::USE)
                
            elsif Input.trigger?(Input::BACK)
                pbPlayCancelSE
                result = false
                break
            elsif Input.repeat?(Input::LEFT)
                if hidden == true || (hidden.is_a?(Array) && hidden[index] )
                    key_sprites[index].reveal_dir(4)
                    key_sprites[index].state = 3
                    index += 1
                elsif puzzle[index] == 4
                    pbPlayCursorSE
                    key_sprites[index].state = 2
                    index += 1
                else
                    pbPlayBuzzerSE
                    key_sprites[index].state = 4
                    wait_timer = 20
                end
            elsif Input.repeat?(Input::RIGHT)
                if hidden == true || (hidden.is_a?(Array) && hidden[index] )
                    key_sprites[index].reveal_dir(6)
                    key_sprites[index].state = 3
                    index += 1
                elsif puzzle[index] == 6
                    pbPlayCursorSE
                    key_sprites[index].state = 2
                    index += 1
                else
                    pbPlayBuzzerSE
                    key_sprites[index].state = 4
                    wait_timer = 20
                end
            elsif Input.repeat?(Input::UP)
                if hidden == true || (hidden.is_a?(Array) && hidden[index] )
                    key_sprites[index].reveal_dir(8)
                    key_sprites[index].state = 3
                    index += 1
                elsif puzzle[index] == 8
                    pbPlayCursorSE
                    key_sprites[index].state = 2
                    index += 1
                else
                    pbPlayBuzzerSE
                    key_sprites[index].state = 4
                    wait_timer = 20
                end
            elsif Input.repeat?(Input::DOWN)
                if hidden == true || (hidden.is_a?(Array) && hidden[index] )
                    key_sprites[index].reveal_dir(2)
                    key_sprites[index].state = 3
                    index += 1
                elsif puzzle[index] == 2
                    pbPlayCursorSE
                    key_sprites[index].state = 2
                    index += 1
                else
                    pbPlayBuzzerSE
                    key_sprites[index].state = 4
                    wait_timer = 20
                end
            end
            if old_index != index
                if index >= puzzle.length
                    if hidden
                        inputs = key_sprites.map(&:dir)
                        if puzzle == inputs
                            pbSEPlay("Voltorb Flip level up")
                            result = true
                            break
                        else
                            pbPlayBuzzerSE
                            wait_timer = 20
                        end
                    else
                        pbSEPlay("Voltorb Flip level up")
                        result = true
                        break
                    end
                else
                    key_sprites[index].state = 1
                    @sprites["puzzle_cursor"].x = key_sprites[index].x - 8
                    @sprites["puzzle_cursor"].y = key_sprites[index].y - 8
                end
            end
        end

        key_sprites.each {|k| k.dispose }
        key_sprites = nil
        @sprites["puzzle_underlay"].visible = false
        @sprites["puzzle_cursor"].visible = false
        return result || false
    end

    def pbWin
        if @win_messages
			@win_messages.each { |s| pbMessage(s + "\1")} 
		else
			message = HackingGameSettings::DEFAULT_WIN_MESSAGE
			if message.nil?
				pbMessage(_INTL("Winner!")) 
			elsif message.is_a?(Array)
				message.each { |s| pbMessage(s + "\1")}
			elsif message == ""
			else
				pbMessage(message)
			end
        end
        @game_result = true
    end

    def pbSceneEdit(game_id = nil)
        @editing = true
        @painting = false
        if game_id
            pbLoadGame(game_id) 
        else
            @game_info = nil
        end
        @sprites["edit_grid"].visible = true
        pbToggleEditMode(true)
        if @game_info.nil?
            @game_info = {
                :game_name => "Game A",
                :game_id => :GameA,
                :starting_position => nil,
                :timer => 0,
                :move_limit => 0,
				:max_lives => 0,
                :fog => nil,
				:bgm => nil,
                :has_finish => false,
                :completed_playtest => false
            }
            if @games[@game_info[:game_id]]
                ("B".."ZZZ").each do |letter|
                    name = "Game " + letter
                    id = name.gsub(/[^a-zA-Z0-9_]/, "").to_sym
                    next if @games[id]
                    @game_info[:game_name] = name
                    @game_info[:game_id] = id
                    break
                end
            end
        end
        @original_name = @game_info[:game_name]
        if @game_info[:starting_position]
            c = convert_coords(@game_info[:starting_position])
            @sprites["player"].x = c[0]
            @sprites["player"].y = c[1]
            @sprites["player"].reset
            @sprites["player"].visible = true
        end
        @coords = (@game_info[:starting_position] ? [*@game_info[:starting_position]] : [0, 0])
        @sprites["cursor"].visible = true
        pbDrawChargeWires if pbGameHasNodesOfType?(:Charge)
        pbDrawEditModeHeader
        update_cursor
        loop do
            Graphics.update
            Input.update
            pbUpdate
            quit = false
            @old_coords = [*@coords]
            if Input.trigger?(Input::USE) && !@painting
                if @node_mode #Node Mode
                    if @nodes[[*@coords]]
                        cmdPaths = -1
                        cmdPuzzle = -1
                        cmdCharge = -1
                        cmdChargeConnect = -1
                        cmdHidePuzzle = -1
                        cmdShowPuzzle = -1
                        cmdDisable = -1
                        cmdKeyReveal = -1
                        cmdReplace = -1
                        cmdDelete = -1
                        cmdAntivirus = -1
                        cmdStart = -1
                        cmdCancel = -1
                        commands = []
                        #commands[cmdPaths = commands.length] = _INTL("Edit Paths")
                        commands[cmdPuzzle = commands.length] = _INTL("Edit Puzzle") unless @nodes[[*@coords]].get_data[:no_puzzle]
                        #commands[cmdHidePuzzle = commands.length] = _INTL("Conceal Puzzle") if !@nodes[[*@coords]].puzzle_hidden && HackingGameSettings::NODE_INFO.any? {|n| n[1][:linked_type] && n[1][:linked_type] == @nodes[[*@coords]].type }
                        #commands[cmdShowPuzzle = commands.length] = _INTL("Reveal Puzzle") if @nodes[[*@coords]].puzzle_hidden
                        commands[cmdCharge = commands.length] = _INTL("Change Initial Charge") if @sprites["node_#{[*@coords]}"].type == :Charge
                        commands[cmdChargeConnect = commands.length] = _INTL("Change Charge Connection") if @sprites["node_#{[*@coords]}"].type == :Charge
                        commands[cmdDisable = commands.length] = _INTL("Edit Access") if @nodes[[*@coords]].get_data[:can_disable]
                        commands[cmdKeyReveal = commands.length] = _INTL("Edit Revealed Keys") if @nodes[[*@coords]].keys_to_reveal
                        commands[cmdReplace = commands.length] = _INTL("Replace") unless @nodes[[*@coords]].type != :Base
                        commands[cmdDelete = commands.length] = _INTL("Delete")
                        current_antivirus = nil
                        if @nodes[[*@coords]].type == :Base && @game_info[:starting_position] != @coords
                            @antivirus.each {|a| break current_antivirus = a[1] if a[1] && a[1].origin == @coords }
                            if current_antivirus
                                commands[cmdAntivirus = commands.length] = _INTL("Edit Antivirus")
                            else
                                commands[cmdAntivirus = commands.length] = _INTL("Add Antivirus")  
                            end
                        end
                        commands[cmdStart = commands.length] = _INTL("Set as Start") unless @nodes[[*@coords]].type != :Base || @game_info[:starting_position] == @coords
                        commands[cmdCancel = commands.length] = _INTL("Cancel")
                        cmd = pbShowCommands(_INTL("Do what with {1} {2}?", @nodes[[*@coords]].get_name, [*@coords]), commands)
                        if cmdPaths >= 0 && cmd == cmdPaths
                            pbToggleEditMode
                            node = @sprites["node_#{[*@coords]}"]
                            neighbors = check_neighbors(node)
                            if !neighbors
                                pbMessage(_INTL("No valid neighboring nodes."))
                            else
                                pbEditPaths(node,neighbors)
                            end
                        elsif cmdPuzzle >= 0 && cmd == cmdPuzzle
                            keys, key_count, hidden = pbPuzzleEditor(@sprites["node_#{[*@coords]}"].puzzle, @sprites["node_#{[*@coords]}"].puzzle_key_count, @sprites["node_#{[*@coords]}"].puzzle_hidden)
                            @sprites["node_#{[*@coords]}"].puzzle = keys.clone
                            @sprites["node_#{[*@coords]}"].puzzle_key_count = key_count
                            @sprites["node_#{[*@coords]}"].puzzle_hidden = hidden
                        # elsif cmdHidePuzzle >= 0 && cmd == cmdHidePuzzle
                        #     if !@nodes.any? {|n| n[1] && HackingGameSettings::NODE_INFO[n[1].type][:linked_type] == @sprites["node_#{[*@coords]}"].type && n[1].id == @sprites["node_#{[*@coords]}"].id }
                        #         pbMessage(_INTL("Add a node that can reveal this node's code first."))
                        #     else
                        #         @nodes[[*@coords]].puzzle_hidden = true
                        #     end
                        elsif cmdDisable >= 0 && cmd == cmdDisable
                            cmddAdd = -1
                            cmddChange = -1
                            cmddRemove = -1
                            cmddHide = -1
                            cmddShow = -1
                            cmddCancel = -1
                            state_string = ""
                            commands_d = []
                            if @sprites["node_#{[*@coords]}"].disabled_info
                                current_lock = ""
                                if @sprites["node_#{[*@coords]}"].disabled_info[:type] == :Light
                                    current_lock += HackingGameSettings::NODE_INFO[:Light][:name_plural] || HackingGameSettings::NODE_INFO[:Light][:name]
                                else
                                    current_lock = HackingGameSettings::NODE_INFO[@sprites["node_#{[*@coords]}"].disabled_info[:type]][:name]
                                    current_lock += " Group" if HackingGameSettings::NODE_INFO[@sprites["node_#{[*@coords]}"].disabled_info[:type]][:needs_group]
                                    current_lock += " #{@sprites["node_#{[*@coords]}"].disabled_info[:id]}"
                                end
                                state_string = _INTL("This node starts disabled.\n({1})", current_lock)
                                commands_d[cmddChange = commands_d.length] = _INTL("Change Access Requirement")
                                if @sprites["node_#{[*@coords]}"].type == :Finish
                                    if @sprites["node_#{[*@coords]}"].hide_when_disabled
                                        commands_d[cmddShow = commands_d.length] = _INTL("Show Node")
                                    else
                                        commands_d[cmddHide = commands_d.length] = _INTL("Hide Node")
                                    end
                                end
                                commands_d[cmddRemove = commands_d.length] = _INTL("Make Always Accessible")
                            else
                                state_string = _INTL("This node is always accessible.")
                                commands_d[cmddAdd = commands_d.length] = _INTL("Make Disabled")
                            end
                            commands_d[cmddCancel = commands_d.length] = _INTL("Cancel")
                            cmd_d = pbShowCommands(state_string, commands_d)
                            if cmddAdd >= 0 && cmd_d == cmddAdd
                                lock = pbChooseAccessMethod(@sprites["node_#{[*@coords]}"])
                                if lock
                                    @sprites["node_#{[*@coords]}"].disabled_info = {
                                        :type => lock[0],
                                        :id => lock[1]
                                    }
                                    @sprites["node_#{[*@coords]}"].toggle_disabled_graphic(true, @editing)
                                    pbMessage(_INTL("Node will now start disabled."))
                                end
                            elsif cmddChange >= 0 && cmd_d == cmddChange
                                lock = pbChooseAccessMethod(@sprites["node_#{[*@coords]}"])
                                if lock
                                    @sprites["node_#{[*@coords]}"].disabled_info = {
                                        :type => lock[0],
                                        :id => lock[1]
                                    }
                                    @sprites["node_#{[*@coords]}"].toggle_disabled_graphic(true, @editing)
                                end
                                pbMessage(_INTL("Node's access requirement updated."))
                            elsif cmddHide >= 0 && cmd_d == cmddHide
                                @sprites["node_#{[*@coords]}"].hide_when_disabled = true if pbConfirmMessage(_INTL("Hide this node while disabled?"))
                            elsif cmddShow >= 0 && cmd_d == cmddShow
                                @sprites["node_#{[*@coords]}"].hide_when_disabled = false if pbConfirmMessage(_INTL("Show this node while disabled?"))
                            elsif cmddRemove >= 0 && cmd_d == cmddRemove
                                @sprites["node_#{[*@coords]}"].disabled_info = nil
                                @sprites["node_#{[*@coords]}"].toggle_disabled_graphic(false, @editing)
                                pbMessage(_INTL("Node is now always accessible."))
                            end
                        elsif cmdKeyReveal >= 0 && cmd == cmdKeyReveal
                            pbRevealKeyEditor(@sprites["node_#{[*@coords]}"])
                        elsif cmdAntivirus >= 0 && cmd == cmdAntivirus
                            if current_antivirus
                                commands_av = [_INTL("Edit Speed"), _INTL("Edit Sight"), _INTL("Delete"), _INTL("Cancel")]
                                cmd_av = pbShowCommands(_INTL("Antivirus {1}\nSpeed: {2}\nSight: {3}", current_antivirus.id, current_antivirus.speed, current_antivirus.sight), commands_av)
                                case cmd_av
                                when 0
                                    params = ChooseNumberParams.new
                                    params.setRange(1, 3)
                                    params.setCancelValue(current_antivirus.speed)
                                    ret = current_antivirus.speed
                                    loop do
                                        params.setInitialValue(ret)
                                        ret = pbMessageChooseNumber(_INTL("What's the antivirus's speed?\nMax: 3"), params)
                                        ret = current_antivirus.speed if ret < 0
                                        break
                                    end
                                    current_antivirus.speed = ret
                                when 1
                                    params = ChooseNumberParams.new
                                    params.setRange(1, 9)
                                    params.setCancelValue(current_antivirus.sight)
                                    ret = current_antivirus.sight
                                    loop do
                                        params.setInitialValue(ret)
                                        ret = pbMessageChooseNumber(_INTL("How far can the antivirus see?\nMax: 9"), params)
                                        ret = current_antivirus.sight if ret < 0
                                        break
                                    end
                                    current_antivirus.sight = ret
                                when 2
                                    if pbConfirmMessage(_INTL("Delete this antivirus?"))
                                        @sprites["virus_#{current_antivirus.id}"].dispose
                                        @antivirus[current_antivirus.id] = nil
                                    end
                                end
                            else
                                new_key = 1
                                loop do
                                    next new_key += 1 if @antivirus[new_key] && !@antivirus[new_key].disposed?
                                    @sprites["virus_#{new_key}"] = HackingAntivirus.new(new_key, *convert_coords, @viewport)
                                    @sprites["virus_#{new_key}"].origin = [*@coords]
                                    @sprites["virus_#{new_key}"].z = 5
                                    @sprites["virus_#{new_key}"].visible = true
                                    @antivirus[new_key] = @sprites["virus_#{new_key}"]
                                    break
                                end
                                pbMessage(_INTL("Added an antivirus at {1}.", @coords))
                            end
                        elsif cmdReplace >= 0 && cmd == cmdReplace
                            pbAddNode(true)
                        elsif cmdCharge >= 0 && cmd == cmdCharge
                            starting_state = pbShowCommands(_INTL("Start drained or charged?"), [_INTL("Drained"), _INTL("Charged")], @sprites["node_#{[*@coords]}"].state)
                            if starting_state >= 0 && starting_state != @sprites["node_#{[*@coords]}"].starting_state
                                @sprites["node_#{[*@coords]}"].state = starting_state
                                @sprites["node_#{[*@coords]}"].starting_state = starting_state
                                @sprites["node_#{[*@coords]}"].refresh
                            end			
                        elsif cmdChargeConnect >= 0 && cmd == cmdChargeConnect
                            cmdchUpperLeft = -1
                            cmdchUpperRight = -1
                            cmdchLowerLeft = -1
                            cmdchLowerRight = -1
                            cmdchCancel = -1
                            commands_ch = []
                            commands_ch[cmdchUpperLeft = commands_ch.length] = _INTL("Upper Left") if @nodes[[@coords[0]-1, @coords[1]-1]] && !@nodes[[@coords[0]-1, @coords[1]-1]].disposed?
                            commands_ch[cmdchUpperRight = commands_ch.length] = _INTL("Upper Right") if @nodes[[@coords[0]+1, @coords[1]-1]] && !@nodes[[@coords[0]+1, @coords[1]-1]].disposed?
                            commands_ch[cmdchLowerLeft = commands_ch.length] = _INTL("Lower Left") if @nodes[[@coords[0]-1, @coords[1]+1]] && !@nodes[[@coords[0]-1, @coords[1]+1]].disposed?
                            commands_ch[cmdchLowerRight = commands_ch.length] = _INTL("Lower Right") if @nodes[[@coords[0]+1, @coords[1]+1]] && !@nodes[[@coords[0]+1, @coords[1]+1]].disposed?
                            commands_ch[cmdchCancel = commands_ch.length] = _INTL("None")
                            dir_check = cmdchCancel
                            if @sprites["node_#{[*@coords]}"].charge_target
                                dir_check = [@sprites["node_#{[*@coords]}"].charge_target[0] - @coords[0], 
                                            @sprites["node_#{[*@coords]}"].charge_target[1] - @coords[1]]
                                if dir_check[1] < 0
                                    if dir_check[0] > 0
                                        dir_check = cmdchUpperRight if cmdchUpperRight >= 0
                                    else
                                        dir_check = cmdchUpperLeft if cmdchUpperLeft >= 0
                                    end
                                else
                                    if dir_check[0] > 0
                                        dir_check = cmdchLowerRight if cmdchLowerRight >= 0
                                    else
                                        dir_check = cmdchLowerLeft if cmdchLowerLeft >= 0
                                    end
                                end
                            end
                            if commands_ch.length > 1
                                cmd_ch = pbShowCommands(_INTL("Connect to another node?"), commands_ch, dir_check)
                                if cmdchUpperLeft >= 0 && cmd_ch == cmdchUpperLeft
                                    @sprites["node_#{[*@coords]}"].charge_target = [@coords[0]-1, @coords[1]-1]
                                elsif cmdchUpperRight >= 0 && cmd_ch == cmdchUpperRight
                                    @sprites["node_#{[*@coords]}"].charge_target = [@coords[0]+1, @coords[1]-1]
                                elsif cmdchLowerLeft >= 0 && cmd_ch == cmdchLowerLeft
                                    @sprites["node_#{[*@coords]}"].charge_target = [@coords[0]-1, @coords[1]+1]
                                elsif cmdchLowerRight >= 0 && cmd_ch == cmdchLowerRight
                                    @sprites["node_#{[*@coords]}"].charge_target = [@coords[0]+1, @coords[1]+1]
                                elsif cmdchCancel >= 0 && cmd_ch == cmdchCancel
                                    @sprites["node_#{[*@coords]}"].charge_target = nil
                                end
                                pbDrawChargeWires
                            end
                        elsif cmdDelete >= 0 && cmd == cmdDelete
                            if @sprites["node_#{[*@coords]}"].id && (!@sprites["node_#{[*@coords]}"].grouped || 
                                        (@sprites["node_#{[*@coords]}"].grouped && @nodes.count {|n| n[1] && n[1].type == @sprites["node_#{[*@coords]}"].type && n[1].id ==  @sprites["node_#{[*@coords]}"].id} == 1))
                                if pbConfirmMessage(_INTL("Delete this node, all paths or disabled node conditions linked to it, and any adjacent paths?")) { pbUpdate }
                                    if @viewing_links
                                        @viewing_links.each { |sprite| sprite.opacity = 255}
                                        @viewing_links = nil
                                    end
                                    @paths.each do |key, path|
                                        next if path.nil?
                                        next unless path.coords_b == @coords || path.coords_a == @coords || path.linked_to?(@sprites["node_#{[*@coords]}"])
                                        path.dispose
                                        @paths[key] = nil
                                    end
                                    @nodes.each do |key, node|
                                        next if node.nil?
                                        next unless node.disabled_info && node.disabled_info[:type] == @sprites["node_#{[*@coords]}"].type && 
                                                node.disabled_info[:id] == @sprites["node_#{[*@coords]}"].id
                                        node.disabled_info = nil
                                        node.toggle_disabled_graphic(false, @editing)
                                    end
                                    @sprites["node_#{[*@coords]}"].dispose
                                    @nodes[[*@coords]] = nil
                                    if @game_info[:starting_position] == @coords
                                        @game_info[:starting_position] = nil
                                        @sprites["player"].visible = false
                                    end
                                end
                            else
                                if pbConfirmMessage(_INTL("Delete this node and any adjacent paths?"))
                                    if @viewing_links
                                        @viewing_links.each { |sprite| sprite.opacity = 255}
                                        @viewing_links = nil
                                    end
                                    @paths.each do |key, path|
                                        next if path.nil?
                                        next unless path.coords_b == @coords || path.coords_a == @coords
                                        path.dispose
                                        @paths[key] = nil
                                    end
                                    @game_info[:has_finish] = false if @sprites["node_#{[*@coords]}"].type == :Finish
                                    @sprites["node_#{[*@coords]}"].dispose
                                    @nodes[[*@coords]] = nil
                                    if @game_info[:starting_position] == @coords
                                        @game_info[:starting_position] = nil
                                        @sprites["player"].visible = false
                                    end
                                    @antivirus.each do |key, a|
                                        next if a.nil?
                                        next unless a.origin == @coords
                                        a.dispose
                                        @antivirus[key] = nil
                                    end
                                end
                            end
                        elsif cmdStart >= 0 && cmd == cmdStart
                            @game_info[:starting_position] = [*@coords]
                            c = convert_coords(@game_info[:starting_position])
                            @sprites["player"].x = c[0]
                            @sprites["player"].y = c[1]
                            @sprites["player"].reset
                            @sprites["player"].visible = true
                            pbMessage(_INTL("Set {1} as the starting position.", @game_info[:starting_position]))
                        end
                    else
                        pbAddNode
                    end
                else # Path Mode
                    node = @sprites["node_#{[*@coords]}"]
                    neighbors = check_neighbors(node)
                    if node.nil? || node.disposed?
                        pbMessage(_INTL("No node at this point."))
                    elsif !neighbors
                        pbMessage(_INTL("No valid neighboring nodes."))
                    else
                        pbEditPaths(node,neighbors)
                    end
                end
                pbPlayDecisionSE
            elsif Input.trigger?(Input::JUMPUP) || Input.trigger?(Input::JUMPDOWN)
                pbToggleEditMode
            elsif Input.trigger?(Input::ACTION)
                @painting = !@painting
                pbDrawEditModeHeader
            elsif Input.trigger?(Input::SPECIAL) && !@painting
                cmdName = -1
                cmdRevertName = -1
                cmdTimer = -1
                cmdMoves = -1
                cmdLives = -1
                cmdFog = -1
                cmdBGM = -1
                cmdExport = -1
                cmdGrid = -1
                cmdCancel = -1
                commands = []
                commands[cmdName = commands.length] = _INTL("Edit Game Name")
                commands[cmdRevertName = commands.length] = _INTL("Revert Game Name") if @game_info[:game_name] != @original_name
                commands[cmdTimer = commands.length] = _INTL("Set Timer")
                commands[cmdMoves = commands.length] = _INTL("Set Move Limit")
                commands[cmdLives = commands.length] = _INTL("Set Max Lives")
                commands[cmdFog = commands.length] = _INTL("Set Fog of War") 
                commands[cmdBGM = commands.length] = _INTL("Set BGM") 
                commands[cmdGrid = commands.length] = @sprites["edit_grid"].visible ? _INTL("Hide Helper Grid") : _INTL("Show Helper Grid")
                commands[cmdExport = commands.length] = _INTL("Save Game")
                commands[cmdCancel = commands.length] = _INTL("Cancel")
                if @game_info[:timer].nil? || @game_info[:timer] == 0
                    timer_string = _INTL("None")
                else
                    t = @game_info[:timer]
                    min = t/60
                    sec = t%60
                    timer_string = "#{@game_info[:timer]}s (#{min}m:#{sec}s)"
                end
                if @game_info[:move_limit].nil? || @game_info[:move_limit] == 0
                    move_string = _INTL("None")
                else
                    move_string = @game_info[:move_limit]
                end
				if @game_info[:max_lives].nil? || @game_info[:max_lives] == 0
                    lives_string = _INTL("Unlmt.")
				else
                    lives_string = @game_info[:max_lives]
				end
                cmd = pbShowCommands(_INTL("Name: {1}\nID: :{2}\nTime: {3}\nMoves: {4}\nLives: {5}", 
						@game_info[:game_name], @game_info[:game_id], timer_string, move_string, lives_string), commands)
                if cmdName >= 0 && cmd == cmdName
                    name = @game_info[:game_name]
                    loop do
                        ret = pbMessageFreeText(_INTL("Enter the name of this game.\\nGame ID will be name without spaces."), name, false, HackingGameSettings::GAME_NAME_LIMIT || 20)
                        ret.strip!
                        if ret.empty?
                            pbMessage(_INTL("The name cannot be blank."))
                            next
                        elsif ret != name
                            new_name = ret
                            new_id = ret.gsub(/[^a-zA-Z0-9_]/, "").to_sym
                            if @games[new_id] && @games[new_id][:name] != @original_name
                                pbMessage(_INTL("A different game already exists with the same name or ID."))
                                next
                            end
                        end
                        name = ret
                        break
                    end
                    @game_info[:game_name] = name.strip
                    @game_info[:game_id] = name.gsub(/[^a-zA-Z0-9_]/, "").to_sym
                elsif cmdRevertName >= 0 && cmd == cmdRevertName
                    if pbConfirmMessage(_INTL("Revert this game's name from {1} to {2}?", @game_info[:game_name], @original_name))
                        @game_info[:game_name] = @original_name
                        @game_info[:game_id] = @original_name.gsub(/[^a-zA-Z0-9_]/, "").to_sym
                    end
                elsif cmdTimer >= 0 && cmd == cmdTimer
                    params = ChooseNumberParams.new
                    params.setRange(0, HackingGameSettings::GAME_MAX_TIMER_LIMIT_SECONDS || 9999)
                    params.setCancelValue(-1)
                    ret = @game_info[:timer] || 0
                    #loop do
                    params.setInitialValue(ret)
                    ret = pbMessageChooseNumber(_INTL("What's the game's time limit (in seconds)?"), params)
                    if ret < 1
                        if pbConfirmMessage(_INTL("Have no time limit?"))
                            ret = 0
                            #break
                        else
                            ret = @game_info[:timer] || 0
                            #break
                        end
                    # else
                    #     break
                    end
                    #end
                    @game_info[:timer] = ret
                elsif cmdMoves >= 0 && cmd == cmdMoves
                    params = ChooseNumberParams.new
                    params.setRange(0, 999)
                    params.setCancelValue(-1)
                    ret = @game_info[:move_limit] || 0
                    #loop do
                        params.setInitialValue(ret)
                        ret = pbMessageChooseNumber(_INTL("What's the game's move limit?"), params)
                        if ret < 1
                            if pbConfirmMessage(_INTL("Have no move limit?"))
                                ret = 0
                                #break
                            else
                                ret = @game_info[:move_limit] || 0
                            end
                        # else
                        #     break
                        end
                    #end
                    @game_info[:move_limit] = ret
                elsif cmdLives >= 0 && cmd == cmdLives
					@game_info[:max_lives] = 0 if @game_info[:max_lives].nil?
                    params = ChooseNumberParams.new
                    params.setRange(0, 9)
                    params.setCancelValue(-1)
                    ret = @game_info[:max_lives] || 0
                    #loop do
                        params.setInitialValue(ret)
                        ret = pbMessageChooseNumber(_INTL("What's the game's max lives?\nMax: 9"), params)
						if ret < 1
                            if pbConfirmMessage(_INTL("Have unlimited lives?"))
                                ret = 0
                                #break
                            else
                                ret = @game_info[:max_lives] || 0
                            end
                        # else
                        #     break
                        end
                    #end
                    @game_info[:max_lives] = ret
                elsif cmdFog >= 0 && cmd == cmdFog
                    commands_f = [_INTL("Turn On"), _INTL("Turn Off")]
                    if @game_info[:fog]
                        commands_f = [_INTL("Keep On"), _INTL("Turn Off")]
                        cmd_f = pbShowCommands(_INTL("Fog of War is On."), commands_f, 0)
                        if cmd_f == 0 
                            if HackingGameSettings::FOG_OF_WAR_SIZES.length > 1
                                fogs = []
                                values = []
                                HackingGameSettings::FOG_OF_WAR_SIZES.each do |key, val|
                                    fogs.push(val[0])
                                    values.push(key)
                                end
                                index = (@game_info[:fog] ? values.index(@game_info[:fog]) : 0)
                                index = 0 if index.nil?
                                cmd_fog = pbShowCommands(_INTL("Which style of fog?"), fogs, index)
                                @game_info[:fog] = values[cmd_fog] if cmd_fog >= 0
                            else
                                @game_info[:fog] = HackingGameSettings::FOG_OF_WAR_SIZES.keys[0] || true
                            end
                        end
                        if cmd_f == 1
                            @game_info[:fog] = nil
                        end
                    else
                        commands_f = [_INTL("Turn On"), _INTL("Keep Off")]
                        cmd_f = pbShowCommands(_INTL("Fog of War is Off."), commands_f, 1)
                        if cmd_f == 0
                            if HackingGameSettings::FOG_OF_WAR_SIZES.length > 1
                                fogs = []
                                values = []
                                HackingGameSettings::FOG_OF_WAR_SIZES.each do |key, val|
                                    fogs.push(val[0])
                                    values.push(val[1])
                                end
                                index = (@game_info[:fog] ? values.index(@game_info[:fog]) : 0)
                                cmd_fog = pbShowCommands(_INTL("Which style of fog?"), fogs, index)
                                @game_info[:fog] = values[cmd_fog] if cmd_fog >= 0
                            else
                                @game_info[:fog] = HackingGameSettings::FOG_OF_WAR_SIZES.keys[0] || true
                            end
                        end
                    end
                elsif cmdBGM >= 0 && cmd == cmdBGM
					oldval = @game_info[:bgm]
                	ret = pbListScreen(_INTL("Choose BGM"), MusicFileLister.new(true, oldval))
					@game_info[:bgm] = ret if ret
                elsif cmdExport >= 0 && cmd == cmdExport
                    ret = pbSaveCustomGame
                    pbMessage(_INTL("Saved #{@game_info[:game_name]}!")) if ret
                elsif cmdGrid >= 0 && cmd == cmdGrid
                    @sprites["edit_grid"].visible = !@sprites["edit_grid"].visible
                end
            elsif Input.trigger?(Input::BACK)
                if pbConfirmMessageSerious(_INTL("Exit editing? (Unsaved changes will be lost.)"))
                    pbPlayCancelSE
                    break
                end
            elsif Input.repeat?(Input::LEFT)
                if @coords[0] == 0
                    pbPlayBuzzerSE
                else
                    @coords[0] -= 1
                    pbPlayCursorSE
                end
            elsif Input.repeat?(Input::RIGHT)
                if @coords[0] == @width
                    pbPlayBuzzerSE
                else
                    @coords[0] += 1
                    pbPlayCursorSE
                end
            elsif Input.repeat?(Input::UP)
                if @coords[1] == 0
                    pbPlayBuzzerSE
                else
                    @coords[1] -= 1
                    pbPlayCursorSE
                end
            elsif Input.repeat?(Input::DOWN)
                if @coords[1] == @height
                    pbPlayBuzzerSE
                else
                    @coords[1] += 1
                    pbPlayCursorSE
                end
            end
            if @coords != @old_coords
                update_cursor
                if @painting
                    if @node_mode
                        if @sprites["node_#{[*@coords]}"].nil? || @sprites["node_#{[*@coords]}"].disposed?
                            @sprites["node_#{[*@coords]}"] = HackingNode.new(:Base, @coords, *convert_coords, @viewport)
                            @sprites["node_#{[*@coords]}"].z = 4
                            @sprites["node_#{[*@coords]}"].visible = true
                            @nodes[[*@coords]] = @sprites["node_#{[*@coords]}"]
                        end
                    else
                        if @coords[0] == @old_coords[0] # Horizontal
                            dir = 0
                            if @coords[1] - @old_coords[1] > 0 # Down
                                coords_a = [*@old_coords]
                                coords_b = [*@coords]
                            else # Up
                                coords_a = [*@coords]
                                coords_b = [*@old_coords]
                            end
                        else # Vertical
                            dir = 1
                            if @coords[0] - @old_coords[0] > 0 # Right
                                coords_a = [*@old_coords]
                                coords_b = [*@coords]
                            else # Left
                                coords_a = [*@coords]
                                coords_b = [*@old_coords]
                            end
                        end
                        coords = coords_a + coords_b
                        if (@sprites["path_#{[*coords]}"].nil? || @sprites["path_#{[*coords]}"].disposed?) &&
                                    @nodes[[*@coords]] && @nodes[[*@old_coords]]
                            @sprites["path_#{[*coords]}"] = HackingPath.new(:Base, dir, coords_a, coords_b, 
		                                *convert_coords(coords_a, dir), @viewport)
                            @sprites["path_#{[*coords]}"].z = 3
                            @sprites["path_#{[*coords]}"].visible = true
                            @paths[[*coords]] = @sprites["path_#{[*coords]}"]
                        end
                    end
                end
            end
        end
        @paths.each { |path| path[1] && path[1].dispose}
        @nodes.each { |node| node[1] && node[1].dispose}
        @antivirus.each { |a| a[1] && a[1].dispose}
        @paths = {}
        @nodes = {}
        @antivirus = {}
        @sprites["cursor"].visible = false
        @sprites["player"].reset
        @sprites["player"].visible = false
        @sprites["fog"]&.visible = false
        @sprites["edit_grid"].visible = false
        @sprites["overlay_charge"].bitmap.clear
        @sprites["overlay_top"].bitmap.clear
		@sprites["overlay_side"].bitmap.clear
        @sprites["overlay_bottom"].bitmap.clear
        @editing = false
    end

    def pbDrawEditModeHeader
        @sprites["overlay_top"].bitmap.clear
        pbDrawTextPositions(@sprites["overlay_top"].bitmap, [[_INTL("-Edit Mode-"), Graphics.width / 2, 4, 2, *HackingGameSettings::BORDER_TEXT_COLORS]])
        pbSetSmallFont(@sprites["overlay_top"].bitmap)
        pbDrawTextPositions(@sprites["overlay_top"].bitmap, [[_INTL("ACTION: Base Painter"), 2, 6, 0, *HackingGameSettings::BORDER_TEXT_COLORS]])
        pbDrawTextPositions(@sprites["overlay_top"].bitmap, [[_INTL("SPECIAL: Settings"), Graphics.width - 2, 6, 1, *HackingGameSettings::BORDER_TEXT_COLORS]]) unless @painting
        pbSetSystemFont(@sprites["overlay_top"].bitmap)
        pbDrawImagePositions(@sprites["overlay_top"].bitmap, [["Graphics/UI/Hacking Game/painter", 0, 28]]) if @painting
    end

	def pbDrawSidePanel
		return unless @game_info[:max_lives] && @game_info[:max_lives] > 0
		@sprites["overlay_side"].bitmap.clear
		imgpos = []
        imgpos.push(["Graphics/UI/Hacking Game/charged", 2, 2]) if @sprites["player"].charged
		(1..@game_info[:max_lives]).reverse_each do |i|
			graphic_index = (@lives >= i ? 0 : 1)
			y = (Graphics.height - 32) / 2 + 16 * (@game_info[:max_lives] + 1) - 32 * i
			imgpos.push(["Graphics/UI/Hacking Game/lives", 0, y, 32*graphic_index, 0, 32, 32])
		end
		pbDrawImagePositions(@sprites["overlay_side"].bitmap, imgpos)
	end

	def pbDrawChargeWires
		imgpos = []
		@nodes.each do |key, node|
			next if node.nil?
			next if node.type != :Charge
			next if !node.charge_target
			target_coords = node.charge_target
			next if @sprites["node_#{[*target_coords]}"].nil? || @sprites["node_#{[*target_coords]}"].disposed?
			size = HackingGameSettings::GRID_SQUARE_SIZE
			coords = nil
			if target_coords[0] > key[0] # Right
				if target_coords[1] > key[1] # Down
					dir = 1 # Down Angle
					coords = [key[0], key[1]]
				else # Up
					dir = 0 # Up Angle
					coords = [key[0], key[1] - 1]
				end
			else # Left
				if target_coords[1] > key[1] # Down
					dir = 0 # Up Angle
					coords = [key[0] - 1, key[1]]
				else # Up
					dir = 1 # Down Angle
					coords = [target_coords[0], target_coords[1]]
				end
			end
			next if coords.nil?
			coords = convert_coords(coords)
			imgpos.push(["Graphics/UI/Hacking Game/charge_wires", coords[0] + size/2, coords[1] + size/2, size*dir, 0, size, size])
		end
		@sprites["overlay_charge"].bitmap.clear
		pbDrawImagePositions(@sprites["overlay_charge"].bitmap, imgpos)
	end

    def pbCheckChargeWireDisables
        nodes_to_update = {}
        @nodes.each do |key, node|
            next if node.nil?
            next if node.type != :Charge
            next if !node.charge_target
            charged_node = @nodes[node.charge_target] 
            next if charged_node.nil?
            next if charged_node.disabled_info && !charged_node.disabled_unlocked
            nodes_to_update[node.charge_target] ||= []
            nodes_to_update[node.charge_target].push(node.state == 0)
        end
        nodes_to_update.each do |key, values|
            node = @nodes[key]
            node.toggle_disabled_graphic(values.any?)
        end
    end

    def pbChooseGame(message = nil, show_playtest_status = false)
        commands = []
        keys = []
        show_playtest_status = false unless HackingGameSettings::SHOW_PLAYTEST_STATUS
        @games.each do |key, data|
            status = ""
            status = " [★]" if show_playtest_status && data[:completed_playtest]
            commands.push(data[:name] + status)
            keys.push(key)
        end
        commands.push(_INTL("Cancel"))
        message ||= _INTL("Select a game.")
        message += "\n[★] - Playtested" if show_playtest_status
        cmd = pbShowCommands(message, commands, helptextaddons: keys)
        return keys[cmd] if cmd >= 0 && keys[cmd]
        return nil
    end

    def pbLoadGame(game)
        data = @games[game]
        @game_info = {
            :game_name => data[:name],
            :game_id => data[:id],
            :starting_position => data[:starting_position],
            :timer => data[:timer],
            :move_limit => data[:move_limit],
			:max_lives => data[:max_lives],
            :fog => data[:fog],
			:bgm => data[:bgm],
            :has_finish => false
        }
        data[:nodes].each do |key, node|
            @sprites["node_#{[*node[:coords]]}"] = HackingNode.new(node[:type], node[:coords], *convert_coords(node[:coords]), @viewport)
            @sprites["node_#{[*node[:coords]]}"].z = 4
            @sprites["node_#{[*node[:coords]]}"].id = node[:id]
            @sprites["node_#{[*node[:coords]]}"].puzzle = node[:puzzle]
            @sprites["node_#{[*node[:coords]]}"].puzzle_key_count = node[:puzzle_key_count]
            @sprites["node_#{[*node[:coords]]}"].puzzle_hidden = node[:puzzle_hidden]
            @sprites["node_#{[*node[:coords]]}"].disabled_info = node[:disabled_info]
            @sprites["node_#{[*node[:coords]]}"].hide_when_disabled = node[:hide_when_disabled]
            @sprites["node_#{[*node[:coords]]}"].keys_to_reveal = node[:keys_to_reveal]
            @sprites["node_#{[*node[:coords]]}"].charge_target = node[:charge_target]
            @sprites["node_#{[*node[:coords]]}"].starting_state = node[:starting_state]
            if node[:starting_state]
                @sprites["node_#{[*node[:coords]]}"].state = node[:starting_state]
                @sprites["node_#{[*node[:coords]]}"].refresh
            end
            @sprites["node_#{[*node[:coords]]}"].visible = true
            @sprites["node_#{[*node[:coords]]}"].toggle_disabled_graphic(true, @editing) if node[:disabled_info]
            @nodes[key] =  @sprites["node_#{[*node[:coords]]}"]
            @game_info[:has_finish] = true if node[:type] == :Finish 
        end
        data[:paths].each do |key, path|
            coords = path[:coords_a] + path[:coords_b]
            @sprites["path_#{[*coords]}"] = HackingPath.new(path[:type], path[:dir], path[:coords_a], path[:coords_b], 
                    *convert_coords(path[:coords_a], path[:dir]), @viewport)
            @sprites["path_#{[*coords]}"].z = 3
            @sprites["path_#{[*coords]}"].visible = true
            @sprites["path_#{[*coords]}"].id = path[:id]
            @sprites["path_#{[*coords]}"].state = path[:state]
            @sprites["path_#{[*coords]}"].starting_state = path[:starting_state]
            @sprites["path_#{[*coords]}"].show_editview if @editing && ([:Light, :Locked, :Checkpoint].include?(path[:type]) || 
                    (@sprites["path_#{[*coords]}"].get_data[:dual_state] && @sprites["path_#{[*coords]}"].state == 1))
            @paths[[*coords]] = @sprites["path_#{[*coords]}"]
        end
        data[:antivirus] = {} if data[:antivirus].nil?
        data[:antivirus].each do |key, a|
            @sprites["virus_#{key}"] = HackingAntivirus.new(a[:id], *convert_coords(a[:origin]), @viewport)
            @sprites["virus_#{key}"].origin = [*a[:origin]]
            @sprites["virus_#{key}"].speed = a[:speed]
            @sprites["virus_#{key}"].sight = a[:sight]
            @sprites["virus_#{key}"].z = 5
            @sprites["virus_#{key}"].visible = true
            @antivirus[key] = @sprites["virus_#{key}"]
        end
    end

    def pbCanMove(dir)
        # ["up", "down", "left", "right"][[8, 2, 4, 6]
        case dir
        when 8 # Up
            new_coords = [@coords[0], @coords[1] - 1]
            if @paths[new_coords + @coords]
                return @paths[new_coords + @coords].can_pass && @nodes[new_coords].visible
            else
                return false
            end
        when 2 # Down
            new_coords = [@coords[0], @coords[1] + 1]
            if @paths[@coords + new_coords]
                return @paths[@coords + new_coords].can_pass && @nodes[new_coords].visible
            else
                return false
            end
        when 4 # Left
            new_coords = [@coords[0] - 1, @coords[1]]
            if @paths[new_coords + @coords]
                return @paths[new_coords + @coords].can_pass && @nodes[new_coords].visible
            else
                return false
            end
        when 6 # Right
            new_coords = [@coords[0] + 1, @coords[1]]
            if @paths[@coords + new_coords]
                return @paths[@coords + new_coords].can_pass && @nodes[new_coords].visible
            else
                return false
            end
        end
        return true
    end

    def update_cursor(startup = false)
        c = convert_coords
        if @editing
            @sprites["cursor"].x = c[0]
            @sprites["cursor"].y = c[1]
            if @viewing_links
                @viewing_links.each { |sprite| next if sprite.disposed?; sprite.opacity = 255}
                @viewing_links = nil
            end
            link_check = pbGetLinks
            if link_check && link_check.length > 1
                @viewing_links = link_check
                @flashframes = 0
            end
        else
            if !startup
                old_coords = [@sprites["player"].x, @sprites["player"].y]
                @sprites["player"].hide_interact
                x_int = ((c[0] - old_coords[0]) / 6).floor
                y_int = ((c[1] - old_coords[1]) / 6).floor
                6.times do
                    Graphics.update
                    pbUpdate
                    @sprites["player"].x += x_int
                    @sprites["player"].y += y_int
                    if @sprites["fog"]&.visible
                        @sprites["fog"].x += x_int
                        @sprites["fog"].y += y_int
                    end
                end
            end
            @sprites["player"].x = c[0]
            @sprites["player"].y = c[1]
            @sprites["player"].show_interact if @nodes[[*@coords]].can_interact? && @nodes[[*@coords]].type != :Finish
            if @sprites["fog"]&.visible
                @sprites["fog"].x = @sprites["player"].x + 16 - @sprites["fog"].width / 2
                @sprites["fog"].y = @sprites["player"].y + 16 - @sprites["fog"].height / 2
            end
            pbPlayCurrentNode unless startup
        end
    end

    def convert_coords(coords = @coords, path_dir = nil)
        return [32 + coords[0] * HackingGameSettings::GRID_SQUARE_SIZE + (path_dir == 1 ? HackingGameSettings::GRID_SQUARE_SIZE/2 : 0), 
				32 + coords[1] * HackingGameSettings::GRID_SQUARE_SIZE + (path_dir == 0 ? HackingGameSettings::GRID_SQUARE_SIZE/2 : 0)]
    end

    def convert_coords_reverse(x, y)
        return [((x - 32) / HackingGameSettings::GRID_SQUARE_SIZE.to_f).round, 
				((y - 32) / HackingGameSettings::GRID_SQUARE_SIZE.to_f).round]
    end

    def check_neighbors(node)
        return false if node.nil?
        coords = node.coords
        n = Array.new(4,nil)
        n[0] = @nodes[[coords[0], coords[1] - 1]] if @nodes[[coords[0], coords[1] - 1]]
        n[1] = @nodes[[coords[0] + 1, coords[1]]] if @nodes[[coords[0] + 1, coords[1]]]
        n[2] = @nodes[[coords[0], coords[1] + 1]] if @nodes[[coords[0], coords[1] + 1]]
        n[3] = @nodes[[coords[0] - 1, coords[1]]] if @nodes[[coords[0] - 1, coords[1]]]
        return false if !n.any?
        return n
    end

    def pbAddNode(replace = false)
        commands = []
        keys = []
        HackingGameSettings::NODE_INFO.each do |key, data|
            next if replace && @sprites["node_#{[*@coords]}"].type == key
            next if key == :Finish && @game_info[:has_finish]
            commands.push(data[:name])
            keys.push(key)
        end
        commands.push(_INTL("Cancel"))
        string = _INTL("Add which node at {1}?", [*@coords])
        string = _INTL("Replace with which node at {1}?", [*@coords]) if replace
        cmd = pbShowCommands(string, commands)
        unless cmd < 0 || cmd == commands.length - 1
            if HackingGameSettings::NODE_INFO[keys[cmd]][:linked_type] 
                if !pbGameHasNodesOfType?(HackingGameSettings::NODE_INFO[keys[cmd]][:linked_type])
                    pbMessage(_INTL("Add a {1} first.", HackingGameSettings::NODE_INFO[HackingGameSettings::NODE_INFO[keys[cmd]][:linked_type]][:name]))
                    return
                end
                ids = pbGetExistingIDNumbers(HackingGameSettings::NODE_INFO[keys[cmd]][:linked_type], true)
                commands_l = []
                nodes_l = []
                ids.each do |id|
                    @nodes.each do |key, node|
                        next if node.nil?
                        next if node.type != HackingGameSettings::NODE_INFO[keys[cmd]][:linked_type]
                        next if node.id != id
                        commands_l.push(node.get_name + " #{node.coords}")
                        nodes_l.push(node)
                    end
                end
                commands_l.push(_INTL("None"))
                cmd_l = pbShowCommands(_INTL("Link to which node?"), commands_l)
                return if cmd_l < 0 || cmd_l == commands_l.length - 1
                if keys[cmd] == :Key && nodes_l[cmd_l]&.puzzle == :Random
                  return pbMessage(_INTL("Linked {1}'s puzzle is set to Always Random and cannot have a Key Node linked to it.", nodes_l[cmd_l].get_data[:name]))
                end
                linked_id = ids[cmd_l]
            end
            starting_state = nil
            if keys[cmd] == :Charge
                starting_state = pbShowCommands(_INTL("Start drained or charged?"), [_INTL("Drained"), _INTL("Charged")], 0, true)
            end
            @sprites["node_#{[*@coords]}"].dispose if @sprites["node_#{[*@coords]}"]
            @sprites["node_#{[*@coords]}"] = HackingNode.new(keys[cmd], @coords, *convert_coords, @viewport)
            @sprites["node_#{[*@coords]}"].z = 4
            if starting_state
                @sprites["node_#{[*@coords]}"].state = starting_state
                @sprites["node_#{[*@coords]}"].starting_state = starting_state
                @sprites["node_#{[*@coords]}"].refresh
            end
			if keys[cmd] == :Charge
				cmdchUpperLeft = -1
				cmdchUpperRight = -1
				cmdchLowerLeft = -1
				cmdchLowerRight = -1
				cmdchCancel = -1
				commands_ch = []
				commands_ch[cmdchUpperLeft = commands_ch.length] = _INTL("Upper Left") if @nodes[[@coords[0]-1, @coords[1]-1]] && !@nodes[[@coords[0]-1, @coords[1]-1]].disposed?
				commands_ch[cmdchUpperRight = commands_ch.length] = _INTL("Upper Right") if @nodes[[@coords[0]+1, @coords[1]-1]] && !@nodes[[@coords[0]+1, @coords[1]-1]].disposed?
				commands_ch[cmdchLowerLeft = commands_ch.length] = _INTL("Lower Left") if @nodes[[@coords[0]-1, @coords[1]+1]] && !@nodes[[@coords[0]-1, @coords[1]+1]].disposed?
				commands_ch[cmdchLowerRight = commands_ch.length] = _INTL("Lower Right") if @nodes[[@coords[0]+1, @coords[1]+1]] && !@nodes[[@coords[0]+1, @coords[1]+1]].disposed?
				commands_ch[cmdchCancel = commands_ch.length] = _INTL("None")
				if commands_ch.length > 1
                	cmd_ch = pbShowCommands(_INTL("Connect to another node?"), commands_ch, cmdchCancel)
					if cmdchUpperLeft >= 0 && cmd_ch == cmdchUpperLeft
						@sprites["node_#{[*@coords]}"].charge_target = [@coords[0]-1, @coords[1]-1]
					elsif cmdchUpperRight >= 0 && cmd_ch == cmdchUpperRight
						@sprites["node_#{[*@coords]}"].charge_target = [@coords[0]+1, @coords[1]-1]
					elsif cmdchLowerLeft >= 0 && cmd_ch == cmdchLowerLeft
						@sprites["node_#{[*@coords]}"].charge_target = [@coords[0]-1, @coords[1]+1]
					elsif cmdchLowerRight >= 0 && cmd_ch == cmdchLowerRight
						@sprites["node_#{[*@coords]}"].charge_target = [@coords[0]+1, @coords[1]+1]
					end
                    if @sprites["node_#{[*@coords]}"].charge_target
                        @nodes[[*@coords]] = @sprites["node_#{[*@coords]}"]
						pbDrawChargeWires
                    end
				end
			end
            @sprites["node_#{[*@coords]}"].visible = true
            if HackingGameSettings::NODE_INFO[keys[cmd]][:needs_id]
                @sprites["node_#{[*@coords]}"].id = pbGenerateIDNumber(keys[cmd])
                pbMessage(_INTL("Added {1}", @sprites["node_#{[*@coords]}"].get_name))
            end
            if HackingGameSettings::NODE_INFO[keys[cmd]][:needs_group]
                @sprites["node_#{[*@coords]}"].id = pbChooseGroupNumber(keys[cmd])
                pbMessage(_INTL("Added {1}", @sprites["node_#{[*@coords]}"].get_name))
            end
            @sprites["node_#{[*@coords]}"].id = linked_id if linked_id
            @nodes[[*@coords]] = @sprites["node_#{[*@coords]}"]
            @game_info[:has_finish] = true if keys[cmd] == :Finish
            pbRevealKeyEditor(@sprites["node_#{[*@coords]}"]) if @sprites["node_#{[*@coords]}"].type == :Key
        end
    end

    def pbGetLinks
        return nil unless @sprites["node_#{[*@coords]}"]&.id
        links = []
        @nodes.each do |key, node|
            next if node.nil?
            next unless (node.id == @sprites["node_#{[*@coords]}"].id && (node.type == @sprites["node_#{[*@coords]}"].type || 
                    (node.get_data[:linked_type] && node.get_data[:linked_type] == @sprites["node_#{[*@coords]}"].type) ||
                    (@sprites["node_#{[*@coords]}"].get_data[:linked_type] && @sprites["node_#{[*@coords]}"].get_data[:linked_type] == node.type))) ||
                    (node.disabled_info && node.disabled_info[:type] == @sprites["node_#{[*@coords]}"].type && 
                    node.disabled_info[:id] == @sprites["node_#{[*@coords]}"].id)
            links.push(node)
        end
        @paths.each do |key, path|
            next if path.nil?
            next unless path.id == @sprites["node_#{[*@coords]}"].id && path.linked_type == @sprites["node_#{[*@coords]}"].type
            links.push(path)
        end
        return nil if links.empty?
        return links
    end

    def pbGenerateIDNumber(type)
        ids = pbGetExistingIDNumbers(type)
        ret = ids.find_index { |n| n.nil? }
        ret = ids.length if ret.nil?
        return ret
    end

    def pbChooseGroupNumber(type)
        params = ChooseNumberParams.new
        params.setRange(1,9)
        params.setCancelValue(-1)
        ret = 1
        loop do
            params.setInitialValue(ret)
            ret = pbMessageChooseNumber(_INTL("Choose the Group ID number."), params)
            if ret < 1
            # elsif @nodes.any? {|n| n[1].type == type && n[1].id == ret}
            #     pbMessage(_INTL("This ID is already used."))
            else
                return ret
            end
        end
    end

    def pbGetExistingIDNumbers(type, filter_nils = false)
        return pbGetExistingGroupIDNumbers(type) if HackingGameSettings::NODE_INFO[type][:needs_group]
        ids = [0]
        @nodes.each do |key, node|
            next if node.nil?
            next if node.type != type
            next if !node.id
            ids[node.id] = node.id
        end
        if filter_nils
            ids.shift
            ids.compact!
            ids.sort!
        end
        return ids
    end

    def pbGetExistingGroupIDNumbers(type)
        ids = []
        @nodes.each do |key, node|
            next if node.nil?
            next if node.type != type
            ids.push(node.id) unless ids.include?(node.id)
        end
        return ids.sort
    end

    def pbChooseAccessMethod(main_node = nil)
        commands = []
        values = []
        HackingGameSettings::NODE_INFO.each do |key, data|
            next unless data[:can_control_disable]
            if data[:needs_group]
                ids = []
                @nodes.each do |key_n, node|
                    next if node.nil?
                    next if node.type != key
                    next if main_node && node.type == main_node.type && node.id == main_node.id
                    next if ids.any? { |a| a[0] == node.id }
                    ids.push([node.id, node])
                end
                ids.sort_by! { |a| a[0]}
                ids.each do |id, node|
                    commands.push(node.get_name) #+ " #{node.coords}")
                    values.push([node.type, node.id])
                end
            else
                ids = pbGetExistingIDNumbers(key, true)
                ids.each do |id|
                    @nodes.each do |key_n, node|
                        next if node.nil?
                        next if node.type != key
                        next if node.id != id
                        next if main_node && node.type == main_node.type && node.id == main_node.id
                        commands.push(node.get_name + " #{node.coords}")
                        values.push([node.type, node.id])
                    end
                end
            end
        end
        if @nodes.any? { |n| n[1] && n[1].type == :Light }
            commands.push(HackingGameSettings::NODE_INFO[:Light][:name_plural] || HackingGameSettings::NODE_INFO[:Light][:name])
            values.push([:Light, nil])
        end
        return nil if commands.empty?
        commands.push(_INTL("Cancel"))
        current_lock = ""
        if main_node && main_node.disabled_info
            current_lock = "\n(Current: "
            if main_node.disabled_info[:type] == :Light
                current_lock += HackingGameSettings::NODE_INFO[:Light][:name_plural] || HackingGameSettings::NODE_INFO[:Light][:name]
                current_lock += ")"
            else
                current_lock += HackingGameSettings::NODE_INFO[main_node.disabled_info[:type]][:name]
                current_lock += " Group" if HackingGameSettings::NODE_INFO[main_node.disabled_info[:type]][:needs_group]
                current_lock += " #{main_node.disabled_info[:id]})"
            end
        end
        cmd = pbShowCommands(_INTL("Link to which node?{1}", current_lock), commands)
        return nil if cmd < 0 || cmd == commands.length - 1
        return values[cmd]
    end

    def pbEditPaths(node, neighbors)
        @sprites["cursor"].setBitmap(_INTL("Graphics/UI/Hacking Game/cursor_paths_add"))
        loop do
            Graphics.update
            Input.update
            pbUpdate
            if (Input.trigger?(Input::BACK) || Input.trigger?(Input::USE)) #&& pbConfirmMessage(_INTL("Stop editing paths?"))
                pbPlayCancelSE
                break
            elsif Input.repeat?(Input::LEFT)
                if neighbors[3]
                    pbPlayCursorSE if pbTogglePath(3, neighbors[3].coords, node.coords)
                else
                    pbPlayBuzzerSE
                end
            elsif Input.repeat?(Input::RIGHT)
                if neighbors[1]
                    pbPlayCursorSE if pbTogglePath(1, node.coords, neighbors[1].coords)
                else
                    pbPlayBuzzerSE
                end
            elsif Input.repeat?(Input::UP)
                if neighbors[0]
                    pbPlayCursorSE if pbTogglePath(0, neighbors[0].coords, node.coords)
                else
                    pbPlayBuzzerSE
                end
            elsif Input.repeat?(Input::DOWN)
                if neighbors[2]
                    pbTogglePath(2, node.coords, neighbors[2].coords)
                else
                    pbPlayBuzzerSE
                end
            elsif Input.trigger?(Input::JUMPUP) || Input.trigger?(Input::JUMPDOWN)
                pbToggleEditMode
                break
            end
        end
        @sprites["cursor"].setBitmap(_INTL("Graphics/UI/Hacking Game/cursor#{@node_mode ? "" : "_paths"}"))
    end

    def pbPuzzleEditor(keys, key_count = nil, hidden = false)
        keys = [] if keys.nil?
        loop do
            old_index ||= 0
            cmdEdit = -1
            cmdRandomize = -1
            cmdRandom = -1
            cmdHide = -1
            cmdCancel = -1
            commands = []
            commands[cmdEdit = commands.length] = ((keys == :Random || keys.empty?) ? _INTL("Add Puzzle") : _INTL("Edit Puzzle"))
            commands[cmdRandomize = commands.length] = _INTL("Randomize")
            commands[cmdRandom = commands.length] = _INTL("Set Always Random")
            commands[cmdHide = commands.length] = _INTL("Edit Hidden")
            commands[cmdCancel = commands.length] = _INTL("Cancel")
            if keys == :Random
                string = _INTL("Current Puzzle: \n{1} Random Keys", key_count)
            elsif keys.empty?
                string = _INTL("Current Puzzle: \nNot set")
            else
                string = _INTL("Current Puzzle: \n{1} Keys", keys.length)
            end
            string += _INTL("\n{1} Hidden", hidden.is_a?(Array) ? "Partially" : "All") if hidden
            cmd = pbShowCommands(string, commands, old_index)
            old_index = cmd
            if cmdEdit >= 0 && cmd == cmdEdit
                @sprites["helpwindow"].width = Graphics.width
                @sprites["helpwindow"].text = _INTL("Enter direction keys to generate the puzzle. Enter Max: {1} keys.", HackingGameSettings::PUZZLE_KEY_LIMIT)
                @sprites["helpwindow"].visible = true
                temp_skip_end = false
                new_keys = []
                if keys.is_a?(Array) && keys.length > 0
                    keys.each do |k|
                        new_keys[new_keys.length] = HackingKey.new(k, 0, false, 0, (Graphics.height - 64) / 2, @viewport)
                    end
                    temp_skip_end = (new_keys.length >= HackingGameSettings::PUZZLE_KEY_LIMIT)
                    new_keys.each_with_index do |k, i|
                        new_x = 8 + (Graphics.width - 64) / 2 - 32 * (new_keys.length - 1) + 64 * i
                        k.x = new_x
                    end
                end
                loop do
                    Graphics.update
                    Input.update
                    pbUpdate
                    old_keys = new_keys.length
                    if (Input.trigger?(Input::USE) && new_keys.length > 0) || (!temp_skip_end && new_keys.length >= HackingGameSettings::PUZZLE_KEY_LIMIT)
                        break if pbConfirmMessage(_INTL("Save this puzzle?"))
                        if pbConfirmMessage(_INTL("Start over?"))
                            new_keys.pop.dispose until new_keys.empty?
                        end
                        temp_skip_end = true
                    elsif Input.trigger?(Input::BACK) 
                        if new_keys.length > 0
                            pbPlayCancelSE
                            new_keys.pop.dispose
                        elsif pbConfirmMessage(_INTL("Stop editing the puzzle?"))
                            break
                        end
                    elsif new_keys.length >= HackingGameSettings::PUZZLE_KEY_LIMIT
                    elsif Input.trigger?(Input::LEFT)
                        new_keys[new_keys.length] = HackingKey.new(4, 0, false, 0, (Graphics.height - 64) / 2, @viewport)
                    elsif Input.trigger?(Input::RIGHT)
                        new_keys[new_keys.length] = HackingKey.new(6, 0, false, 0, (Graphics.height - 64) / 2, @viewport)
                    elsif Input.trigger?(Input::UP)
                        new_keys[new_keys.length] = HackingKey.new(8, 0, false, 0, (Graphics.height - 64) / 2, @viewport)
                    elsif Input.trigger?(Input::DOWN)
                        new_keys[new_keys.length] = HackingKey.new(2, 0, false, 0, (Graphics.height - 64) / 2, @viewport)
                    end
                    if old_keys != new_keys.length
                        pbPlayCursorSE
                        temp_skip_end = false
                        new_keys.each_with_index do |k, i|
                            new_x = 8 + (Graphics.width - 64) / 2 - 32 * (new_keys.length - 1) + 64 * i
                            k.x = new_x
                        end
                    end
                end
                @sprites["helpwindow"].visible = false
                keys = new_keys.map(&:dir)
                key_count = nil
                new_keys.each {|k| k.dispose }
            elsif cmdRandomize >= 0 && cmd == cmdRandomize
                params = ChooseNumberParams.new
                params.setRange(1, HackingGameSettings::PUZZLE_KEY_LIMIT)
                params.setCancelValue(-1)
                params.setInitialValue((keys.is_a?(Array) && keys.length > 0) ? keys.length : (HackingGameSettings::PUZZLE_KEY_LIMIT / 2.0).ceil)
                params.setInitialValue(key_count) if key_count
                ret = pbMessageChooseNumber(_INTL("How many keys?\nMax: {1}", HackingGameSettings::PUZZLE_KEY_LIMIT), params)
                if ret > 0
                    keys = []
                    ret.times { keys.push([2, 4, 6, 8].sample) }
                    key_count = nil
                end
            elsif cmdRandom >= 0 && cmd == cmdRandom
                params = ChooseNumberParams.new
                params.setRange(1, HackingGameSettings::PUZZLE_KEY_LIMIT)
                params.setCancelValue(-1)
                params.setInitialValue((keys.is_a?(Array) && keys.length > 0) ? keys.length : (HackingGameSettings::PUZZLE_KEY_LIMIT / 2.0).ceil)
                params.setInitialValue(key_count) if key_count
                ret = pbMessageChooseNumber(_INTL("How many keys?\nMax: {1}", HackingGameSettings::PUZZLE_KEY_LIMIT), params)
                if ret > 0
                    keys = :Random
                    key_count = ret
                end
            elsif cmdHide >= 0 && cmd == cmdHide
                cmdhShow = -1
                cmdhHide = -1
                cmdhPartial = -1
                cmdhCancel = -1
                commands_h = []
                commands_h[cmdhShow = commands_h.length] = _INTL("Show All") if hidden
                commands_h[cmdhHide = commands_h.length] = _INTL("Hide All") if !hidden || hidden.is_a?(Array)
                commands_h[cmdhPartial = commands_h.length] = _INTL("Hide Some")
                commands_h[cmdhCancel = commands_h.length] = _INTL("Cancel")
                string_h = _INTL("No hidden keys.")
                if hidden
                    if hidden.is_a?(Array)
                        string_h = _INTL("Some keys hidden.")
                    else
                        string_h = _INTL("All keys hidden.")
                    end
                end
                cmd_h = pbShowCommands(string_h, commands_h)
                if cmdhShow >= 0 && cmd_h == cmdhShow
                    hidden = nil
                elsif cmdhHide >= 0 && cmd_h == cmdhHide
                    hidden = true
                elsif cmdhPartial >= 0 && cmd_h == cmdhPartial
                    if keys.nil? || keys == :Random || (keys.is_a?(Array) && keys.empty?)
                        pbMessage(_INTL("You can only hide specific keys if you manually define keys first."))
                    else
                        hidden = Array.new(keys.length, hidden) unless hidden.is_a?(Array)
                        index_h = 0
                        keys_h = [*keys]
                        key_sprites = []

                        @sprites["helpwindow"].width = Graphics.width
                        @sprites["helpwindow"].text = _INTL("Choose which keys to hide.")
                        @sprites["helpwindow"].visible = true
                        keys_h.each_with_index do |k, i|
                            x = 8 + (Graphics.width - 64) / 2 - 32 * (keys_h.length - 1) + 64 * i
                            y = (Graphics.height - 64) / 2
                            key_sprites[i] = HackingKey.new(k, 0, false, x, y, @viewport)
                            if hidden[i]
                                key_sprites[i].hidden = true
                                key_sprites[i].state = 3
                            end
                        end
                        @sprites["puzzle_cursor"].x = key_sprites[index_h].x - 8
                        @sprites["puzzle_cursor"].y = key_sprites[index_h].y - 8
                        @sprites["puzzle_cursor"].visible = true
                        @sprites["puzzle_underlay"].visible = true
                        loop do
                            Graphics.update
                            Input.update
                            pbUpdate
                            old_index_h = index_h
                            if Input.trigger?(Input::USE)
                                if hidden[index_h]
                                    hidden[index_h] = false
                                    key_sprites[index_h].hidden = false
                                    key_sprites[index_h].state = 0
                                else
                                    hidden[index_h] = true
                                    key_sprites[index_h].hidden = true
                                    key_sprites[index_h].state = 3
                                end
                            elsif Input.trigger?(Input::BACK) && pbConfirmMessage(_INTL("Save these hidden keys?"))
                                break

                            elsif Input.trigger?(Input::LEFT)
                                index_h -= 1
                                index_h = 0 if index_h < 0
                            elsif Input.trigger?(Input::RIGHT)
                                index_h += 1
                                index_h = keys_h.length - 1 if index_h >= keys_h.length
                            end
                            if old_index_h != index_h
                                pbPlayCursorSE
                                @sprites["puzzle_cursor"].x = key_sprites[index_h].x - 8
                            end
                        end
                        if hidden.all? { |h| h == false }
                            hidden = false
                        elsif hidden.all? 
                            hidden = true
                        end
                        @sprites["helpwindow"].visible = false
                        @sprites["puzzle_underlay"].visible = false
                        @sprites["puzzle_cursor"].visible = false
                        key_sprites.each {|k| k.dispose }
                    end


                end
            else
                return keys, key_count, hidden
            end
        end

    end

    def pbRevealKeyEditor(node)
        node = @sprites["node_#{[*@coords]}"] if node.nil?
        parent = nil
        @nodes.each do |key, n|
            next if n.type != node.get_data[:linked_type]
            next if n.id != node.id
            parent = n
            break
        end
        if parent.nil?
            return pbMessage(_INTL("Could not find a linked {1}.", HackingGameSettings::NODE_INFO[node.get_data[:linked_type]][:name]))
        elsif !parent.puzzle_hidden
            return pbMessage(_INTL("Linked {1} does not have any hidden keys.", parent.get_data[:name]))
        elsif parent.puzzle == :Random
            return pbMessage(_INTL("Linked {1}'s puzzle is set to Always Random and cannot have a Key Node linked to it.", parent.get_data[:name]))
        end
        puzzle = parent.puzzle
        hidden = parent.puzzle_hidden
        hidden = Array.new(puzzle.length, hidden) unless hidden.is_a?(Array)
        index = 0
        selections = node.keys_to_reveal || Array.new(puzzle.length)
        key_sprites = []
        @sprites["helpwindow"].width = Graphics.width
        @sprites["helpwindow"].text = _INTL("Choose which keys to reveal with this node.")
        @sprites["helpwindow"].visible = true
        puzzle.each_with_index do |k, i|
            x = 8 + (Graphics.width - 64) / 2 - 32 * (puzzle.length - 1) + 64 * i
            y = (Graphics.height - 64) / 2
            key_sprites[i] = HackingKey.new(k, 0, false, x, y, @viewport)
            if hidden[i]
                key_sprites[i].hidden = true
                key_sprites[i].state = selections[i] ? 2 : 3
            elsif selections[i]
                selections[i] = nil
            end
        end
        @sprites["puzzle_cursor"].x = key_sprites[index].x - 8
        @sprites["puzzle_cursor"].y = key_sprites[index].y - 8
        @sprites["puzzle_cursor"].visible = true
        @sprites["puzzle_underlay"].visible = true
        loop do
            Graphics.update
            Input.update
            pbUpdate
            old_index = index
            if Input.trigger?(Input::USE)
                if hidden[index]
                    if selections[index]
                        selections[index] = false
                        key_sprites[index].state = 3
                    else
                        selections[index] = true
                        key_sprites[index].state = 2
                    end
                else
                    pbPlayBuzzerSE
                end
            elsif Input.trigger?(Input::BACK)
                if selections.all? { |h| h.nil? || h == false}
                    pbMessage(_INTL("Choose at least one key to reveal."))
                elsif pbConfirmMessage(_INTL("Save these keys?"))
                    break
                end
            elsif Input.trigger?(Input::LEFT)
                index -= 1
                index = 0 if index < 0
            elsif Input.trigger?(Input::RIGHT)
                index += 1
                index = puzzle.length - 1 if index >= puzzle.length
            end
            if old_index != index
                pbPlayCursorSE
                @sprites["puzzle_cursor"].x = key_sprites[index].x - 8
            end
        end
        @sprites["helpwindow"].visible = false
        @sprites["puzzle_underlay"].visible = false
        @sprites["puzzle_cursor"].visible = false
        key_sprites.each {|k| k.dispose }
        node.keys_to_reveal = selections
    end

    def pbRevealKeys(node)
        node = @sprites["node_#{[*@coords]}"] if node.nil?
        parent = nil
        @nodes.each do |key, n|
            next if n.type != node.get_data[:linked_type]
            next if n.id != node.id
            parent = n
            break
        end
        if parent.nil?
            Console.echo_warn _INTL("Could not find a linked {1}.", HackingGameSettings::NODE_INFO[node.get_data[:linked_type]][:name])
            return false
        elsif !parent.puzzle_hidden
            Console.echo_warn _INTL("Linked {1} does not have any hidden keys.", parent.get_data[:name])
            return false
        end
        puzzle = parent.puzzle
        keys_to_reveal = [*node.keys_to_reveal]
        if puzzle.length != keys_to_reveal.length
            Console.echo_warn _INTL("Possible mismatch for this {1}'s data.", node.get_data[:name])
        end
        pbDrawTextPositions(@sprites["puzzle_underlay_title"].bitmap,[[_INTL("Read-Only"), Graphics.width / 2, Graphics.height - 96, 2, 
                HackingGameSettings::BORDER_TEXT_COLORS[0], HackingGameSettings::BORDER_TEXT_COLORS[1]]])
        @sprites["puzzle_underlay"].visible = true
        actual_keys = []
        first = keys_to_reveal.index(true)
        last = keys_to_reveal.rindex(true)
        keys_to_reveal.each_with_index do |k, i|
            next if i < first || i > last
            next if puzzle[i].nil?
            if k
                actual_keys.push(puzzle[i])
            else
                actual_keys.push(nil)
            end
        end
        key_sprites = []
        actual_keys.each_with_index do |k, i|
            next if k.nil?
            x = 8 + (Graphics.width - 64) / 2 - 32 * (actual_keys.length - 1) + 64 * i
            y = (Graphics.height - 64) / 2
            key_sprites[i] = HackingKey.new(k, 3, false, x, y, @viewport)
        end
        loop do
            Graphics.update
            Input.update
            pbUpdate
            if Input.trigger?(Input::USE) || Input.trigger?(Input::BACK)
                pbPlayCursorSE
                break
            end
        end
        @sprites["puzzle_underlay_title"].bitmap.clear
        @sprites["puzzle_underlay"].visible = false
        key_sprites.each {|k| k&.dispose }
        return true
    end

    def pbToggleEditMode(val = nil)
        @node_mode = val || !@node_mode
        @sprites["cursor"].setBitmap(_INTL("Graphics/UI/Hacking Game/cursor#{@node_mode ? "" : "_paths"}"))
        @sprites["overlay_bottom"].bitmap.clear
        if @node_mode
            pbDrawImagePositions(@sprites["overlay_bottom"].bitmap, [["Graphics/UI/Hacking Game/editview_mode_toggle", (Graphics.width - 96) / 2, Graphics.height - 32, 0, 0, 96, 32]])
            pbDrawTextPositions(@sprites["overlay_bottom"].bitmap, [[_INTL("Node Mode"), (Graphics.width - 96) / 2 - 8, Graphics.height - 24, 1, *HackingGameSettings::BORDER_TEXT_COLORS]])
            pbSetSmallFont(@sprites["overlay_bottom"].bitmap)
            pbDrawTextPositions(@sprites["overlay_bottom"].bitmap, [[_INTL("JUMPDOWN"), (Graphics.width + 96) / 2 + 8, Graphics.height - 22, 0, *HackingGameSettings::BORDER_TEXT_COLORS]])
            pbSetSystemFont(@sprites["overlay_bottom"].bitmap)
        else
            pbDrawImagePositions(@sprites["overlay_bottom"].bitmap, [["Graphics/UI/Hacking Game/editview_mode_toggle", (Graphics.width - 96) / 2, Graphics.height - 32, 0, 32, 96, 32]])
            pbDrawTextPositions(@sprites["overlay_bottom"].bitmap, [[_INTL("Path Mode"), (Graphics.width + 96) / 2 + 8, Graphics.height - 24, 0, *HackingGameSettings::BORDER_TEXT_COLORS]])
            pbSetSmallFont(@sprites["overlay_bottom"].bitmap)
            pbDrawTextPositions(@sprites["overlay_bottom"].bitmap, [[_INTL("JUMPUP"), (Graphics.width - 96) / 2 - 8, Graphics.height - 22, 1, *HackingGameSettings::BORDER_TEXT_COLORS]])
            pbSetSystemFont(@sprites["overlay_bottom"].bitmap)
        end

    end

    def pbToggleTimer(val = nil)
        val = false unless [1, 3].include?(HackingGameSettings::TIMER_TYPE)
        if val.nil?
            @sprites["timer_bg"].visible = !@sprites["timer_bg"].visible
            @sprites["timer_bar"].visible = !@sprites["timer_bar"].visible
        else
            @sprites["timer_bg"].visible = val
            @sprites["timer_bar"].visible = val
        end
    end
    
    def pbTogglePath(dir, coords_a, coords_b, path_type = nil)
        coords = coords_a + coords_b
        if @sprites["path_#{[*coords]}"] && !@sprites["path_#{[*coords]}"].disposed?
            if pbConfirmMessage(_INTL("Delete {1}?", @sprites["path_#{[*coords]}"].get_name))
                @sprites["path_#{[*coords]}"].dispose
                @paths[[*coords]] = nil
            end
        else
            if path_type.nil?
                commands = []
                keys = []
                HackingGameSettings::PATH_INFO.each do |key, data|
                    commands.push(data[:name])
                    keys.push(key)
                end
                commands.push(_INTL("None"))
                case dir
                when 0
                    dir_name = _INTL("upwards")
                when 1
                    dir_name = _INTL("to the right")
                when 2
                    dir_name = _INTL("downwards")
                when 3
                    dir_name = _INTL("to the left")
                end
                cmd = pbShowCommands(_INTL("Add which path {1}?", dir_name), commands)
                return false if cmd < 0 || cmd == commands.length - 1
                path_type = keys[cmd]
            end

            if HackingGameSettings::NODE_INFO[HackingGameSettings::PATH_INFO[path_type][:linked_type]] &&
                        (HackingGameSettings::NODE_INFO[HackingGameSettings::PATH_INFO[path_type][:linked_type]][:needs_group] || 
                        HackingGameSettings::NODE_INFO[HackingGameSettings::PATH_INFO[path_type][:linked_type]][:needs_id])
                if !pbGameHasNodesOfType?(HackingGameSettings::PATH_INFO[path_type][:linked_type])
                    pbMessage(_INTL("Add a {1} first.", HackingGameSettings::NODE_INFO[HackingGameSettings::PATH_INFO[path_type][:linked_type]][:name]))
                    return false
                end
            end
            if HackingGameSettings::PATH_INFO[path_type][:linked_type]
                if  HackingGameSettings::NODE_INFO[HackingGameSettings::PATH_INFO[path_type][:linked_type]][:needs_group]
                    ids = pbGetExistingIDNumbers(HackingGameSettings::PATH_INFO[path_type][:linked_type], true)
                    commands = []
                    ids.each { |id| commands.push(_INTL("Group {1}", id)) }
                    commands.push(_INTL("None"))
                    cmd = pbShowCommands(_INTL("Link to which {1} group?", HackingGameSettings::PATH_INFO[HackingGameSettings::PATH_INFO[path_type][:linked_type]][:name]), commands)
                    return false if cmd < 0 || cmd == commands.length - 1
                    linked_id = ids[cmd]
                elsif HackingGameSettings::PATH_INFO[path_type][:linked_type] == :Light
                    starting_state = 1
                else
                    ids = pbGetExistingIDNumbers(HackingGameSettings::PATH_INFO[path_type][:linked_type], true)
                    commands = []
                    ids.each do |id|
                        @nodes.each do |key, node|
                            next if node.nil?
                            next if node.type != HackingGameSettings::PATH_INFO[path_type][:linked_type]
                            next if node.id != id
                            commands.push(node.get_name + " #{node.coords}")
                        end
                    end
                    commands.push(_INTL("None"))
                    cmd = pbShowCommands(_INTL("Link to which node?"), commands)
                    return false if cmd < 0 || cmd == commands.length - 1
                    linked_id = ids[cmd]
                    if HackingGameSettings::PATH_INFO[path_type][:dual_state]
                        commands_s = [_INTL("Revealed"), _INTL("Concealed")]
                        cmd_s = pbShowCommands(_INTL("Which state?"), commands_s, 0, true)
                        starting_state = cmd_s
                    end
                end
            end
            dir = 0 if dir == 2
            dir = 1 if dir == 3
            @sprites["path_#{[*coords]}"] = HackingPath.new(path_type, dir, coords_a, coords_b, 
                    *convert_coords(coords_a, dir), @viewport)
            @sprites["path_#{[*coords]}"].z = 3
            @sprites["path_#{[*coords]}"].visible = true
            @sprites["path_#{[*coords]}"].id = linked_id if linked_id
            if [:Locked, :Checkpoint].include?(path_type) 
                @sprites["path_#{[*coords]}"].state = 1
                @sprites["path_#{[*coords]}"].show_editview if @editing
            end
            if starting_state 
                @sprites["path_#{[*coords]}"].state = starting_state
                @sprites["path_#{[*coords]}"].starting_state = starting_state
                @sprites["path_#{[*coords]}"].show_editview if @editing && starting_state == 1
            end
            @paths[[*coords]] = @sprites["path_#{[*coords]}"]
        end
        return true
    end

    def pbEndScene
        pbFadeOutAndHide(@sprites) { pbUpdate }
        pbDisposeSpriteHash(@sprites)
        @viewport.dispose
    end
  
    def pbUpdate
        if @editing && @viewing_links
            case @flashframes
            when 0..40
                op = 255
                @viewing_links.each { |sprite| next if sprite.disposed?; sprite.opacity = op}
            when 41..60
                op = 255.0 - (255.0 * ((@flashframes - 40) / 20.0))
                @viewing_links.each { |sprite| next if sprite.disposed?; sprite.opacity = op}
            when 61..70
                op = 0
                @viewing_links.each { |sprite| next if sprite.disposed?; sprite.opacity = op}
            when 71..90
                op = 255.0 * ((@flashframes - 70) / 20.0)
                @viewing_links.each { |sprite| next if sprite.disposed?; sprite.opacity = op}
            end
            @flashframes += 1
            @flashframes = 0 if @flashframes > 90
        end
        if @timer
            if Essentials::VERSION.include?("20")
                @timer -= 1
                @timer = 0 if @timer <= 0
                if [1, 3].include?(HackingGameSettings::TIMER_TYPE)
                    width = [@timer_inc_per_frame * @timer, 0].max
                    bar_index = 0
                    if width <= @timer_start_width / 4
                        @sprites["timer_bar"].setBitmap(_INTL("Graphics/UI/Hacking Game/timer_bar")) unless @timer_fourth_passed
                        bar_index = 2
                        @timer_fourth_passed = true
                    elsif width <= @timer_start_width / 2
                        @sprites["timer_bar"].setBitmap(_INTL("Graphics/UI/Hacking Game/timer_bar")) unless @timer_half_passed
                        bar_index = 1
                        @timer_half_passed = true
                    end
                    @sprites["timer_bar"].src_rect.set(0, bar_index * @timer_bar_height, width, @timer_bar_height)
                end
                if [2, 3].include?(HackingGameSettings::TIMER_TYPE)
                    curtime = @timer / Graphics.frame_rate
                    curtime = 0 if curtime < 0
                    min = curtime / 60
                    sec = curtime % 60
                    text = _ISPRINTF("{1:02d}:{2:02d}", min, sec)
                    @sprites["overlay_top"].bitmap.clear
                    pbDrawTextPositions(@sprites["overlay_top"].bitmap,[[text, Graphics.width / 2, 4, 2, *HackingGameSettings::BORDER_TEXT_COLORS]])
                end
            else
                curtime = @timer - $stats.play_time + @timer_start
                curtime = 0 if curtime < 0
                if [1, 3].include?(HackingGameSettings::TIMER_TYPE)
                    width = [(1 - (($stats.play_time - @timer_start) / @timer)) * @timer_start_width, 0].max
                    bar_index = 0
                    if width <= @timer_start_width / 4
                        @sprites["timer_bar"].setBitmap(_INTL("Graphics/UI/Hacking Game/timer_bar")) unless @timer_fourth_passed
                        bar_index = 2
                        @timer_fourth_passed = true
                    elsif width <= @timer_start_width / 2
                        @sprites["timer_bar"].setBitmap(_INTL("Graphics/UI/Hacking Game/timer_bar")) unless @timer_half_passed
                        bar_index = 1
                        @timer_half_passed = true
                    end
                    @sprites["timer_bar"].src_rect.set(0, bar_index * @timer_bar_height, width, @timer_bar_height)
                end
                if [2, 3].include?(HackingGameSettings::TIMER_TYPE)
                    min = curtime / 60
                    sec = curtime % 60
                    text = _ISPRINTF("{1:02d}:{2:02d}", min, sec)
                    @sprites["overlay_top"].bitmap.clear
                    pbDrawTextPositions(@sprites["overlay_top"].bitmap,[[text, Graphics.width / 2, 4, 2, *HackingGameSettings::BORDER_TEXT_COLORS]])
                end
				@timer = 0 if curtime <= 0
            end
        end
        unless @editing || @antivirus.empty? || @restarting
            @antivirus.each do |key, a|
                next unless a.visible
                if a.active && !a.moving_to
                    if !pbPFCanSeePlayer?(a, 18)
                        a.deactivate
                        if !@antivirus.any? { |av| av[1] && av[1].active }
                            @sprites["frame"].setBitmap(_INTL("Graphics/UI/Hacking Game/bg_frame"))
                        end
                    else
                        path = pbPFShortestPath(a, @old_coords)
                        if path && path.length > 1
                            a.moving_to = path[0..1] 
                            #a.moving_to.push((a.speed - 4).abs * 11)
                            a.moving_to.push([32,16,11][a.speed - 1])
                            a.moving_to.push(HackingGameSettings::GRID_SQUARE_SIZE.to_f / a.moving_to[2])
                        end
                    end
                elsif !a.active && pbPFCanSeePlayer?(a)
                    a.activate
					pbSEPlay("Exclaim")
                    @sprites["frame"].setBitmap(_INTL("Graphics/UI/Hacking Game/bg_frame_alert"))
                    path = pbPFShortestPath(a, @old_coords)
                    if path && path.length > 1
                        a.moving_to = path[0..1] 
                        #a.moving_to.push((a.speed - 4).abs * 11)
                        a.moving_to.push([32,24,16][a.speed - 1])
                        a.moving_to.push(HackingGameSettings::GRID_SQUARE_SIZE.to_f / a.moving_to[2])
                    end
                # elsif a.active && !pbPFCanSeePlayer?(a, 18)
                #     a.deactivate
                end
                next unless a.active
                if a.pbTouchingPlayer?(@sprites["player"])
                    if @sprites["player"].charged
                        @sprites["player"].charged = false
                        pbDrawSidePanel
                        a.visible = false
                        a.active = false
                        if !@antivirus.any? { |av| av[1] && av[1].active }
                            @sprites["frame"].setBitmap(_INTL("Graphics/UI/Hacking Game/bg_frame"))
                        end
					elsif @lives && @lives > 1
						@lives -= 1
						pbDrawSidePanel
						pbSEPlay("Battle damage weak")
						@restarting = true
						break
					elsif @lives && @lives == 1
						@lives -= 1
						pbDrawSidePanel
						pbSEPlay("Voltorb Flip explosion")
						15.times { Graphics.update }
                        pbMessage(_INTL("The antivirus got you!"))
                        @game_result = false
                    elsif @game_result.nil?
						pbSEPlay("Voltorb Flip explosion")
                        pbMessage(_INTL("The antivirus got you!"))
                        @game_result = false
                    end
                end
                if a.moving_to
                    old_coords = a.moving_to[0]
                    new_coords = a.moving_to[1]
                    diff = a.moving_to[3]
                    x_int = (new_coords[0] - old_coords[0]) * diff
                    y_int = (new_coords[1] - old_coords[1]) * diff
                    a.x += x_int.round
                    a.y += y_int.round
                    a.moving_to[2] -= 1
                    if a.moving_to[2] <= 0
                        c = convert_coords(new_coords)
                        a.x = c[0]
                        a.y = c[1]
                        a.moving_to = nil
                    end
                end
            end
        end
        pbUpdateSpriteHash(@sprites)
    end
  
    def pbShowCommands(helptext, commands, index = 0, force_choice = false, helptextaddons: nil)
        #return UIHelper.pbShowCommands(@sprites["helpwindow"], helptext, commands, index) { pbUpdate }
        return pbShowCommandsCustom(helptext, commands, index, force_choice, helptextaddons: helptextaddons) { pbUpdate }
    end

    def pbShowCommandsCustom(helptext, commands, initcmd = 0, forced = false, helptextaddons: nil)
        helpwindow = @sprites["helpwindow"]
        ret = -1
        oldvisible = helpwindow.visible
        helpwindow.visible        = helptext ? true : false
        helpwindow.letterbyletter = false
        helptext ||= ""
        helpwindow.text           = helptext #|| ""
        cmdwindow = Window_CommandPokemon.new(commands)
        cmdwindow.index = initcmd
        begin
        cmdwindow.viewport = helpwindow.viewport
        pbBottomRight(cmdwindow)
        helpwindow.resizeHeightToFit(helpwindow.text, Graphics.width - cmdwindow.width)
        pbBottomLeft(helpwindow)
        loop do
            Graphics.update
            Input.update
            yield
            cmdwindow.update
            if helptextaddons 
				helpwindow.text = helptext + (helptextaddons[cmdwindow.index] ? "\nID: :" + helptextaddons[cmdwindow.index].to_s : "")
        		helpwindow.resizeHeightToFit(helpwindow.text, Graphics.width - cmdwindow.width)
				pbBottomLeft(helpwindow)
            end
            if Input.trigger?(Input::BACK) && !forced
                ret = -1
                pbPlayCancelSE
                break
            end
            if Input.trigger?(Input::USE)
                ret = cmdwindow.index
                pbPlayDecisionSE
                break
            end
        end
        ensure
        cmdwindow&.dispose
        end
        helpwindow.visible = oldvisible
        return ret
    end

    def pbSaveCustomGame
        if !@game_info[:has_finish]
            pbMessage(_INTL("There is no Finish Node set."))
            return false
        end
        if !@game_info[:starting_position]
            pbMessage(_INTL("There is no starting position set."))
            return false
        end
        @nodes.delete_if { |key, val| val.nil? }
        @paths.delete_if { |key, val| val.nil? }
        @antivirus.delete_if { |key, val| val.nil? }
        if @nodes.any? { |n| (n[1].puzzle.nil? || n[1].puzzle.empty?) && !n[1].get_data[:no_puzzle] }
            unless pbConfirmMessage(_INTL("Some nodes don't have puzzles set. These will be randomized. Is that okay?"))
                return false
            end
        end
        has_fog_removal = pbGameHasNodesRemovesFog?
        if has_fog_removal && !@game_info[:fog] && pbConfirmMessage(_INTL("Game includes fog removal nodes, but fog of war is not turned on. Turn it on?"))
            if HackingGameSettings::FOG_OF_WAR_SIZES.length > 1
                fogs = []
                values = []
                HackingGameSettings::FOG_OF_WAR_SIZES.each do |key, val|
                    fogs.push(val[0])
                    values.push(key)
                end
                index = (@game_info[:fog] ? values.index(@game_info[:fog]) : 0)
                cmd_fog = pbShowCommands(_INTL("Which style of fog?"), fogs, index)
                @game_info[:fog] = values[cmd_fog] if cmd_fog >= 0
            else
                @game_info[:fog] = HackingGameSettings::FOG_OF_WAR_SIZES.values[0] || true
            end
        end
        export_data = {
            :id => @game_info[:game_id],
            :name => @game_info[:game_name],
            :starting_position => [*@game_info[:starting_position]],
            :timer => @game_info[:timer],
            :move_limit => @game_info[:move_limit],
			:max_lives => @game_info[:max_lives],
            :fog => @game_info[:fog],
            :bgm => @game_info[:bgm],
            :completed_playtest => false,
            :nodes => {},
            :paths => {},
            :antivirus => {}
        }
        @nodes.each do |key, node|
            export_data[:nodes][node.coords] = { :type => node.type, 
                :coords => node.coords, :id => node.id, :puzzle => node.puzzle, 
                :puzzle_key_count => node.puzzle_key_count, :puzzle_hidden => node.puzzle_hidden,
                :disabled_info => node.disabled_info, :hide_when_disabled => node.hide_when_disabled, 
                :keys_to_reveal => node.keys_to_reveal, :starting_state => node.starting_state,
			 	:charge_target => node.charge_target }
        end
        @paths.each do |key, path|
            export_data[:paths][path.coords_a + path.coords_b] = { :type => path.type, 
                :dir => path.dir, :coords_a => path.coords_a, :coords_b => path.coords_b, 
                :id => path.id, :state => path.state, :starting_state => path.starting_state }
        end
        @antivirus.each do |key, a|
            export_data[:antivirus][key] = { :id => a.id, :origin => a.origin, 
                :speed => a.speed, :sight => a.sight }
        end
        pbSaveGame(export_data[:id], export_data)
        @games = pbGetAvailableGames
        return true
    end

    def pbGameHasNodesOfType?(type)
        return @nodes.any? {|n| n[1] && n[1].type == type}
    end

    def pbGameHasNodesRemovesFog?
        return @nodes.any? { |n| n[1] && n[1].get_data[:removes_fog] }
    end

end