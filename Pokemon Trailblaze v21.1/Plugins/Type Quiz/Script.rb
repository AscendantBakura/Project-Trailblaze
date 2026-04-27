#===============================================================================
# * Type Quiz - by FL (Credits will be apreciated)
#===============================================================================
#
# This script is for Pokémon Essentials. It's a type quiz minigame where
# the player must guess the multiplier of a certain type effectiveness in a
# certain type combination. You can use it by a normal message choice or by
# a scene screen.
#
# The proportion of correct answers are made in way to every answer will have
# the same amount of being correct.
#
#== INSTALLATION ===============================================================
#
# Put it above main OR convert into a plugin. If you gonna use the scene screen, 
# create a "Type Quiz" folder at Graphics/UI and put the pictures "background" 
# and "vs".
#
#== HOW TO USE =================================================================
#
# To use the quiz in standard text message, calls the script
# 'TypeQuiz::Question.new.show_choice' in a conditional branch and handle 
# when the player answers correctly and incorrectly, respectively.
#
# To use the scene screen, use the script command 'TypeQuiz.start_scene(X)' 
# where X is the number of total questions. This method will return the number
# of question answered correctly.
#
#===============================================================================

if defined?(PluginManager) && !PluginManager.installed?("Type Quiz")
  PluginManager.register({                                                 
    :name    => "Type Quiz",                                        
    :version => "1.1",                                                     
    :link    => "https://www.pokecommunity.com/showthread.php?t=306090",
    :credits => "FL"
  })
end

module TypeQuiz
  # If false the last two answers merge into one, resulting in five answers
  SIX_ANSWERS = true
  # In scene points the right answer if the player miss
  SHOW_RIGHT_ANSWER = true
  # Allows single type at defense
  ALLOW_SINGLE_TYPE = false
  # When true, player can press cancel button and exit
  CAN_EXIT = false
  
  class Question
    attr_reader   :attack_type
    attr_reader   :defense1_type
    attr_reader   :defense2_type
    attr_reader   :result
    
    TYPE_AVAILABLE = [
      :NORMAL,:FIGHTING,:FLYING,:POISON,:GROUND,:ROCK,:BUG,:GHOST,:STEEL,:FIRE,
      :WATER,:GRASS,:ELECTRIC,:PSYCHIC,:ICE,:DRAGON,:DARK,:FAIRY
    ]
    ANSWERS = [ 
      _INTL("4x"),_INTL("2x"),_INTL("Normal"),_INTL("1/2")
    ]+ (SIX_ANSWERS ? [_INTL("1/4"),_INTL("Immune")] : [_INTL("1/4 or immune")])
    TYPE_RESULTS = [
      ANSWERS.size-1,4,3,nil,2,nil,nil,nil,1,nil,nil,nil,nil,nil,nil,nil,0
    ] # 4 being normal effective
    
    def initialize(answer=-1)
      answer = rand(ANSWERS.size) if answer==-1
      @result = -1
      while (
        @result!=answer || 
        (!ALLOW_SINGLE_TYPE && @defense1_type==@defense2_type)
      )
        @attack_type = TYPE_AVAILABLE[rand(TYPE_AVAILABLE.size)]
        @defense1_type = TYPE_AVAILABLE[rand(TYPE_AVAILABLE.size)]
        @defense2_type = TYPE_AVAILABLE[rand(TYPE_AVAILABLE.size)]
        @result = TYPE_RESULTS[type_effectiveness]
      end  
    end

    def type_effectiveness
      ret = Bridge.type_effectiveness(@attack_type, @defense1_type)
      if @defense1_type != @defense2_type
        ret *= Bridge.type_effectiveness(@attack_type, @defense2_type)
      end
      return ret
    end
    
    def show_choice
      attack_type_name = Bridge.type_name(@attack_type)
      defense_type_name = Bridge.type_name(@defense1_type)
      if @defense1_type!=@defense2_type
        defense_type_name += "/"+Bridge.type_name(@defense2_type)
      end
      question=_INTL(
        "{1} move versus {2} pokémon? What is the damage?",
        attack_type_name, defense_type_name
      )
      return Bridge.message(question, ANSWERS, 0) == @result
    end  
  end
    
  class Scene
    MARGIN = 32
    TEXT_COLORS = [Color.new(248,248,248), Color.new(112,112,112)]
    TEXT_CHOICE_COLORS = [Color.new(72,72,72), Color.new(160,160,160)]
    
    def update
      pbUpdateSpriteHash(@sprites)
    end
    
    def start_scene(questions)
      @questions_total=questions
      @questions_count=0
      @questions_right=0
      @index=0
      pbBGMPlay(Bridge.bgm_path)
      @sprites = {} 
      @viewport=Viewport.new(0,0,Graphics.width,Graphics.height)
      @viewport.z=99999
      @typebitmap = AnimatedBitmap.new(Bridge.type_image_path)
      @sprites["background"]=IconSprite.new(0,0,@viewport)
      @sprites["background"].setBitmap("Graphics/UI/Type Quiz/background")
      @sprites["background"].x= (
        Graphics.width - @sprites["background"].bitmap.width
      )/2
      @sprites["background"].y= (
        Graphics.height-@sprites["background"].bitmap.height
      )/2    
      @sprites["vs"] = IconSprite.new(0,0,@viewport)
      @sprites["vs"].setBitmap("Graphics/UI/Type Quiz/vs")
      @sprites["vs"].x = Graphics.width*3/4-@sprites["vs"].bitmap.width/2-12
      @sprites["vs"].y = Graphics.height*3/4-@sprites["vs"].bitmap.height/2-32
      @sprites["arrow"] = IconSprite.new(MARGIN+8,0,@viewport)
      @sprites["overlay"] = BitmapSprite.new(
        Graphics.width, Graphics.height, @viewport
      )
      pbSetSystemFont(@sprites["overlay"].bitmap)
      next_question
      pbFadeInAndShow(@sprites) { update }
    end
    
    def next_question
      @questions_count+=1
      return if finished?
      @question=Question.new
      @answer_label=""
      @sprites["arrow"].setBitmap(Bridge.sel_arrow_path)
      refresh
      @index=2 # Normal effective index
      update_cursor
    end  
  
    def refresh
      @sprites["overlay"].bitmap.clear 
      draw_text(@sprites["overlay"].bitmap)
      draw_type_image(@sprites["overlay"].bitmap)
    end

    def draw_text(overlay)
      left_text = ""
      center_text = ""
      right_text = ""
      # Remove below lineto stop showing player score
      left_text=_INTL("Correct: {1}", @questions_right)
      center_text=@answer_label # Remove to stop showing Correct/Wrong message
      right_text=@questions_count.to_s # Remove to stop showing question count
      right_text+="/" if right_text!=""
      right_text+=@questions_total.to_s # Remove to stop showing question total
      right_text = _INTL("Question: {1}", right_text) if right_text!=""
      text_positions=[
        [
          left_text, MARGIN, Graphics.height/2-74,
          false, TEXT_COLORS[0], TEXT_COLORS[1]
        ],[
          center_text, Graphics.width/2, Graphics.height/2-74,
          2, TEXT_COLORS[0], TEXT_COLORS[1]
        ],[
          right_text,Graphics.width-MARGIN,Graphics.height/2-74,
          true, TEXT_COLORS[0], TEXT_COLORS[1]
        ]
      ]
      for i in 0...Question::ANSWERS.size
        text_positions.push([
          Question::ANSWERS[i], 2*MARGIN, Graphics.height/2+i*40-34,
          false, TEXT_CHOICE_COLORS[0], TEXT_CHOICE_COLORS[1]
        ])
      end 
      Bridge.draw_text_positions(overlay,text_positions)
    end

    def draw_type_image(overlay)
      x = Graphics.width*3/4-40
      def_y = Graphics.height*3/4+40
      type_atk_rect = Rect.new(
        0,Bridge.type_icon_index(@question.attack_type)*28,64,28
      )
      type_def1_rect = Rect.new(
        0,Bridge.type_icon_index(@question.defense1_type)*28,64,28
      )
      type_def2_rect = Rect.new(
        0,Bridge.type_icon_index(@question.defense2_type)*28,64,28
      )
      overlay.blt(x,Graphics.height/2-36,@typebitmap.bitmap,type_atk_rect)
      if @question.defense1_type==@question.defense2_type
        overlay.blt(x,def_y,@typebitmap.bitmap,type_def1_rect)
      else
        overlay.blt(x-34,def_y,@typebitmap.bitmap,type_def1_rect)
        overlay.blt(x+34,def_y,@typebitmap.bitmap,type_def2_rect)
      end
    end
    
    def update_cursor
      @sprites["arrow"].y = Graphics.height/2+@index*40-40
    end

    def on_choose
      if @question.result==@index 
        @answer_label=_INTL("Correct!")
        pbSEPlay(Bridge.correct_se_path) 
        @questions_right+=1
      else
        @answer_label=_INTL("Wrong!")
        pbPlayBuzzerSE
        if SHOW_RIGHT_ANSWER
          @index=@question.result
          @sprites["arrow"].setBitmap(Bridge.sel_arrow_white_path)
          update_cursor
          refresh
          Bridge.wait(1.0)
        end
      end
      refresh
      Bridge.wait(1.0)
    end
  
    def main
      loop do
        Graphics.update
        Input.update
        self.update
        if finished?
          Bridge.message(
            _INTL("Game end! {1} correct answer(s)!",@questions_right)
          )
          return @questions_right
        elsif @answer_label!=""
          next_question
        else  
          if Input.trigger?(Input::C)
            on_choose
          end  
          if Input.trigger?(Input::B) && CAN_EXIT
            pbPlayCancelSE
            return -1
          end
          if Input.repeat?(Input::UP)
            pbPlayCursorSE
            @index = (@index==0 ? Question::ANSWERS.size : @index)-1
            update_cursor
          elsif Input.repeat?(Input::DOWN)
            pbPlayCursorSE
            @index = @index==(Question::ANSWERS.size-1) ? 0 : @index+1
            update_cursor
          end
        end
      end
    end
    
    def finished?
      return @questions_count>@questions_total
    end  
  
    def end_scene
      $game_map.autoplay if Bridge.bgm_path && !Bridge.bgm_path.empty?
      pbFadeOutAndHide(@sprites) { update }
      pbDisposeSpriteHash(@sprites)
      @typebitmap.dispose
      @viewport.dispose
    end
  end
  
  class Screen
    def initialize(scene)
      @scene=scene
    end
  
    def start_screen(questions=10)
      @scene.start_scene(questions)
      ret=@scene.main
      @scene.end_scene
      return ret
    end
  end
  
  def self.start_scene(questions=10)
    ret=nil
    pbFadeOutIn(99999){
      scene = Scene.new
      screen = Screen.new(scene)
      ret = screen.start_screen(questions)
    }
    return ret
  end

  module Bridge
    module_function

    def major_version
      ret = 0
      if defined?(Essentials)
        ret = Essentials::VERSION.split(".")[0].to_i
      elsif defined?(ESSENTIALS_VERSION)
        ret = ESSENTIALS_VERSION.split(".")[0].to_i
      elsif defined?(ESSENTIALSVERSION)
        ret = ESSENTIALSVERSION.split(".")[0].to_i
      end
      return ret
    end

    MAJOR_VERSION = major_version
    
    def message(string, commands = nil, cmdIfCancel = 0, &block)
      if MAJOR_VERSION < 20
        return Kernel.pbMessage(string, commands, cmdIfCancel, &block)
      end
      return pbMessage(string, commands, cmdIfCancel, &block)
    end

    def wait(seconds)
      pbWait(MAJOR_VERSION < 21 ? (seconds*40).round : seconds)
    end

    def type_name(type)
      return PBTypes.getName(getID(PBTypes, type)) if MAJOR_VERSION < 19
      return GameData::Type.get(type).name
    end

    def type_icon_index(type)
      return getID(PBTypes, type) if MAJOR_VERSION < 19
      return GameData::Type.get(type).icon_position
    end

    # 2 being normal effective
    def type_effectiveness(attacker_type, opponent_type)
      if MAJOR_VERSION < 19
        return PBTypes.getEffectiveness(
          getID(PBTypes,attacker_type),getID(PBTypes,opponent_type)
        )
      end
      effectiveness = Effectiveness.calculate(attacker_type, opponent_type)
      if Effectiveness.ineffective?(effectiveness)
        return 0
      elsif Effectiveness.not_very_effective?(effectiveness)
        return 1
      elsif Effectiveness.super_effective?(effectiveness)
        return 4
      end
      return 2
    end
    
    def draw_text_positions(bitmap,textPos)
      if MAJOR_VERSION < 20
        for single_text_pos in textPos
          single_text_pos[2] -= MAJOR_VERSION==19 ? 12 : 6
        end
      end
      return pbDrawTextPositions(bitmap,textPos)
    end

    def type_image_path
      return _INTL("Graphics/Pictures/types") if MAJOR_VERSION < 21
      return _INTL("Graphics/UI/types")
    end

    def sel_arrow_path
      return _INTL("Graphics/Pictures/selarrow") if MAJOR_VERSION < 21
      return _INTL("Graphics/UI/sel_arrow")
    end

    def sel_arrow_white_path
      return _INTL("Graphics/Pictures/selarrowwhite") if MAJOR_VERSION < 17
      return _INTL("Graphics/Pictures/selarrow_white") if MAJOR_VERSION < 21
      return _INTL("Graphics/UI/sel_arrow_white")
    end

    def correct_se_path
      return "itemlevel" if MAJOR_VERSION < 17
      return "Pkmn move learnt"
    end

    def bgm_path
      return "evolv" if MAJOR_VERSION < 17
      return "Evolution"
    end
  end
end