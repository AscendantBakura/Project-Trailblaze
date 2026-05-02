module HackingGameSettings

    NODE_INFO = {
        :Base => {
            :name => _INTL("Base Node"),
            :graphic => _INTL("Graphics/UI/Hacking Game/node_base"),
            :no_puzzle => true
        },
        :Locked => {
            :name => _INTL("Locked Node"),
            :graphic => _INTL("Graphics/UI/Hacking Game/node_locked"),
            :needs_id => true,
            :start_state => 1,
            :can_disable => true,
            :can_control_disable => true
        },
        :Key => {
            :name => _INTL("Key Node"),
            :graphic => _INTL("Graphics/UI/Hacking Game/node_key"),
            :linked_type => :Locked,
            :no_puzzle => true,
            :can_disable => true
        },
        :Swap => {
            :name => _INTL("Swap Node"),
            :graphic => _INTL("Graphics/UI/Hacking Game/node_swap"),
            :needs_id => true,
            :can_disable => true
        },
        :Checkpoint => {
            :name => _INTL("Checkpoint Node"),
            :graphic => _INTL("Graphics/UI/Hacking Game/node_checkpoint"),
            :needs_group => true,
            :start_state => 1,
            :can_disable => true,
            :can_control_disable => true
        },
        :Light => {
            :name => _INTL("Light Node"),
            :name_plural => _INTL("Lights"),
            :graphic => _INTL("Graphics/UI/Hacking Game/node_light"),
            :removes_fog => true,
            :start_state => 1,
            :can_disable => true,
            :can_control_disable => true
        },
        :Charge => {
            :name => _INTL("Charge Node"),
            :graphic => _INTL("Graphics/UI/Hacking Game/node_charge"),
            :no_puzzle => true
        },
        :Finish => {
            :name => _INTL("Finish Node"),
            :graphic => _INTL("Graphics/UI/Hacking Game/node_finish"),
            :no_puzzle => true,
            :can_disable => true
        },
    }

    PATH_INFO = {
        :Base => {
            :name => _INTL("Base Path"),
            :graphic => _INTL("Graphics/UI/Hacking Game/path_base")
        },
        :Locked => {
            :name => _INTL("Locked Path"),
            :graphic => _INTL("Graphics/UI/Hacking Game/path_unlocked"),
            :linked_type => :Locked
        },
        :Swap => {
            :name => _INTL("Swap Path"),
            :graphic => _INTL("Graphics/UI/Hacking Game/path_swap"),
            :linked_type => :Swap,
            :dual_state => true
        },
        :Checkpoint => {
            :name => _INTL("Checkpoint Path"),
            :graphic => _INTL("Graphics/UI/Hacking Game/path_checkpoint"),
            :linked_type => :Checkpoint
        },
        :Light => {
            :name => _INTL("Light Path"),
            :graphic => _INTL("Graphics/UI/Hacking Game/path_light"),
            :linked_type => :Light
        },
    }

    GRID_SQUARE_SIZE = 32

    GAME_NAME_LIMIT = 20

    GAME_MAX_TIMER_LIMIT_SECONDS = 9999

    PUZZLE_KEY_LIMIT = 7

    SHOW_PLAYTEST_STATUS = true

end

class HackingGame_Scene
    def pbGetAvailableGames(pull_data = false)
        return $game_temp.hacking_games if $game_temp.hacking_games && !pull_data
		filecheck = pbRgssExists?("Data/HackingGame.rxdata")
		if filecheck
            data = load_data("Data/HackingGame.rxdata")
        else
            hash = {}
            File.open("Data/HackingGame.rxdata", "wb") { |f| Marshal.dump(hash, f) }
            data = load_data("Data/HackingGame.rxdata")
        end
        data = data.sort_by { |key, value| value[:name] }.to_h
        $game_temp.hacking_games = data
        
        return data
    end

    def pbSaveGame(id, data)
        hash = pbGetAvailableGames(true)
        hash[id] = data
        save_data(hash,"Data/HackingGame.rxdata")
        pbGetAvailableGames(true)
    end

    def pbSavePlaytest(id)
        hash = pbGetAvailableGames(true)
        hash[id][:completed_playtest] = true
        save_data(hash,"Data/HackingGame.rxdata")
        pbGetAvailableGames(true)
    end

    def pbDeleteGame(id)
        hash = pbGetAvailableGames(true)
        hash.delete(id)
        save_data(hash,"Data/HackingGame.rxdata")
        pbGetAvailableGames(true)
    end

    def pbExportGameToFile(game)
        data = @games[game]
        #path = "Hacking Game #{data[:name]}.hxgm"
        path = HackingGameSettings::GAME_FILEPATH
        filename = "HackingGame-#{data[:name]}.hxgm"
        File.open(path + filename, "wb") { |f| Marshal.dump(data, f) }
        path = _INTL("your game folder") if path == ""
        pbMessage(_INTL("Exported to \"{1}\" in {2}.", filename, path))
        return true
    end

    def pbImportGameFromFile
        files = []
        # pbRgssChdir(".") { files.concat(Dir.glob("*.hxgm")) }
		if Essentials::VERSION.include?("20")
        	pbRgssChdir(HackingGameSettings::GAME_FILEPATH) { files.concat(Dir.glob("*.hxgm")) }
		else
			BattleAnimationEditor::pbRgssChdir(HackingGameSettings::GAME_FILEPATH) { files.concat(Dir.glob("*.hxgm")) }
		end
        cmdwin = pbListWindow(files, 320)
        cmdwin.height = Graphics.height / 2
        cmdwin.x =  (Graphics.width - cmdwin.width) / 2
        cmdwin.y =  (Graphics.height - cmdwin.height) / 2
        cmdwin.viewport = @viewport
        cmdwin.visible = files.length > 0
        path = HackingGameSettings::GAME_FILEPATH
        path = _INTL("your game folder") if path == ""
        @sprites["helpwindow"].width = Graphics.width
        @sprites["helpwindow"].text = _INTL("Choose a file to import from {1}.", path)
        @sprites["helpwindow"].resizeHeightToFit(@sprites["helpwindow"].text)
        pbBottomLeft(@sprites["helpwindow"])
        @sprites["helpwindow"].visible = true
        data = nil
        loop do
            Graphics.update
            Input.update
            cmdwin.update
            if Input.trigger?(Input::USE) && files.length > 0
                begin
                    File.open(HackingGameSettings::GAME_FILEPATH + files[cmdwin.index]) do |file|
                        data = Marshal.load(file)
                        if !data.is_a?(Hash)
                            data = nil
                            next
                        end
                    end
                end
                break
            elsif files.length <= 0
                path = HackingGameSettings::GAME_FILEPATH
                path = _INTL("your game folder") if path == ""
                pbMessage(_INTL("No files found in {1}.", path))
                break
            elsif Input.trigger?(Input::BACK)
                break
            end
        end
        cmdwin.dispose
        @sprites["helpwindow"].visible = false
        return data
    end
end

class Game_Temp
    attr_accessor :hacking_games
end