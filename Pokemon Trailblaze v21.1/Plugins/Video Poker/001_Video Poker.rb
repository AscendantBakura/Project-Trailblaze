#===============================================================================
# * Video Poker - by FL (Credits will be apreciated)
#===============================================================================
#
# This script is for Pokémon Essentials. It's a Video Poker minigame,
# specifically the Jokers Wild used in Dragon Quest. It uses coins like a Game
# Corner game.
#
#== HOW TO USE =================================================================
#
# Use the script command 'VideoPoker.play(X,Y)' where X is the minimum wage and
# Y is the maximum wage. Example: 'VideoPoker.play(1,9)'. The player must have
# the Coin Case to play.
#
#== NOTES ======================================================================
#
# The card spriteset accept other measures.
#
# In 'generate_deck' you can add or remove cards (like jokers), but the deck
# can't have more than 2 Jokers since it would make the time for combinations
# detection increase considerably.
#
# In 'generate_combination_array' you can edit the combinations.
#
#===============================================================================

module VideoPoker
  # Only continues Double or Nothing if the next possible earning is this
  # value or lower.
  DOUBLE_OR_NOTHING_COIN_LIMIT = 1_000

  # Limit of Double or Nothing rounds in a row (doesn't dount draw). Put 
  # zero to disable it.
  DOUBLE_OR_NOTHING_TRIES_LIMIT = 5

  # when true, in double or nothing asks to player if the card is higher 
  # or lower than the face up card. If false, always treat as if he
  # answered "higher", making the game harder.
  ASK_IN_DOUBLE_OR_NOTHING = false 

  # When true, makes the cards go lower and hide the message window sometimes.
  # Player also need to confirm after the result. Use this mode when using big
  # card graphics.
  HIDE_MESSAGE_WHEN_SELECTING = false

  # When false, combinations values are on board rather than in a windows.
  COMBINATIONS_IN_A_WINDOW = true

  # When true, if a combination was found when the player is selecting cards to
  # hold, the combination will be highlighted.
  ALWAYS_HIGHLIGHT_COMBINATION = true

  # When true, if a combination was found when the player is selecting cards to
  # hold, the cards that form the combination will be flashing. Only works if
  # ALWAYS_HIGHLIGHT_COMBINATION is true
  FLASH_CARDS = true

  # Only trigger big bonus ME if the value is equals or greater of this number.
  # Otherwise plays other ME. Doesn't consider wager, just the bonus.
  MIN_BONUS_FOR_BIG_ME = 50


  HEART   = 1
  DIAMOND = 2
  CLUB    = 3
  SPADE   = 4

  ACE   = 1
  JACK  = 11
  QUEEN = 12
  KING  = 13
  JOKER = 99

  VALUE_SEQUENCE = [ACE, 2, 3, 4, 5, 6, 7, 8, 9, 10, JACK, QUEEN, KING]
  DOUBLE_OR_NOTHING = [2, 3, 4, 5, 6, 7, 8, 9, 10, JACK, QUEEN, KING, ACE] # You can add a Joker here

  HIGHEST_CARD = KING

  HAND_SIZE = 5

  def self.generate_deck
    ret = [ 
      Card.new(ACE  , HEART  ),
      Card.new(ACE  , DIAMOND),
      Card.new(ACE  , SPADE  ),
      Card.new(ACE  , CLUB   ),
      Card.new(2    , HEART  ),
      Card.new(2    , DIAMOND),
      Card.new(2    , SPADE  ),
      Card.new(2    , CLUB   ),
      Card.new(3    , HEART  ),
      Card.new(3    , DIAMOND),
      Card.new(3    , SPADE  ),
      Card.new(3    , CLUB   ),
      Card.new(4    , HEART  ),
      Card.new(4    , DIAMOND),
      Card.new(4    , SPADE  ),
      Card.new(4    , CLUB   ),
      Card.new(5    , HEART  ),
      Card.new(5    , DIAMOND),
      Card.new(5    , SPADE  ),
      Card.new(5    , CLUB   ),
      Card.new(6    , HEART  ),
      Card.new(6    , DIAMOND),
      Card.new(6    , SPADE  ),
      Card.new(6    , CLUB   ),
      Card.new(7    , HEART  ),
      Card.new(7    , DIAMOND),
      Card.new(7    , SPADE  ),
      Card.new(7    , CLUB   ),
      Card.new(8    , HEART  ),
      Card.new(8    , DIAMOND),
      Card.new(8    , SPADE  ),
      Card.new(8    , CLUB   ),
      Card.new(9    , HEART  ),
      Card.new(9    , DIAMOND),
      Card.new(9    , SPADE  ),
      Card.new(9    , CLUB   ),
      Card.new(10   , HEART  ),
      Card.new(10   , DIAMOND),
      Card.new(10   , SPADE  ),
      Card.new(10   , CLUB   ),
      Card.new(JACK , HEART  ),
      Card.new(JACK , DIAMOND),
      Card.new(JACK , SPADE  ),
      Card.new(JACK , CLUB   ),
      Card.new(QUEEN, HEART  ),
      Card.new(QUEEN, DIAMOND),
      Card.new(QUEEN, SPADE  ),
      Card.new(QUEEN, CLUB   ),
      Card.new(KING , HEART  ),
      Card.new(KING , DIAMOND),
      Card.new(KING , SPADE  ),
      Card.new(KING , CLUB   ),
      # Remove/copy the below code line to remove/add more jokers.
      # Game works only with 2 at max.
      Card.new(JOKER         ),
    ]
    validate_deck(ret)
    return ret
  end

  # Generates all combinations with points.
  # Hand is already sorted. True hand include Jokers
  def self.generate_combination_array
    ret = []
    ret.push(Combination.new(_INTL("Royal Flush"), 500, proc{|hand, _true_hand|
      next nil if hand.map{|card| card.suit}.uniq.size > 1
      next hand.map{|card| card.value} == [ACE, 10, JACK, QUEEN, KING] ? hand : nil
    }))
    ret.push(Combination.new(_INTL("{1} of a Kind",5), 100, proc{|hand, _true_hand|
      # Doesn't use get_cards_of_value since the below line is faster
      next hand.map{|card| card.value}.uniq.size==1 ? hand : nil
    }))
    ret.push(Combination.new(_INTL("Straight Flush"), 50, proc{|hand, _true_hand|
      next nil if hand.map{|card| card.suit}.uniq.size > 1
      next process_straight(hand)
    }))
    ret.push(Combination.new(_INTL("{1} of a Kind",4), 20, proc{|hand, _true_hand|
      next VideoPoker.process_n_of_kind(4, hand)
    }))
    ret.push(Combination.new(_INTL("Full House"), 10, proc{|hand, _true_hand|
      # Since 4 of a kind was already checked
      next hand.map{|card| card.value}.uniq.size==2 ? hand : nil
    }))
    ret.push(Combination.new(_INTL("Flush"), 5, proc{|hand, _true_hand|
      next hand.map{|card| card.suit}.uniq.size==1 ? hand : nil
    }))
    ret.push(Combination.new(_INTL("Straight"), 4, proc{|hand, _true_hand|
      next process_straight(hand)
    }))
    ret.push(Combination.new(_INTL("{1} of a Kind",3), 2, proc{|hand, _true_hand|
      next VideoPoker.process_n_of_kind(3, hand)
    }))
    ret.push(Combination.new(_INTL("2 Pairs"), 1, proc{|hand, _true_hand|
      value_array = hand.map{|card| card.value}.uniq
      # Since already checked for 3 of a kind, this was enough
      next nil if value_array.size != 3
      pair_array = []
      for value in value_array
        cards_of_value = get_cards_of_value(value, hand)
        pair_array+=cards_of_value if cards_of_value.size == 2
      end
      next pair_array.size==4 ? pair_array : nil
    }))
    ret.push(Combination.new(_INTL("Joker"), 1, proc{|_hand, true_hand|
      array = nil
      for card in true_hand
        next if card.value != JOKER
        array = [card] 
        break
      end
      next array
    }))
    return ret
  end

  # Return cards with value as value
  def self.get_cards_of_value(value, hand)
    ret = []
    for card in hand
      next if card.value != value
      ret.push(card)
    end
    return ret
  end

  def self.process_n_of_kind(n, hand)
    value_array = hand.map{|card| card.value}.uniq
    return if value_array.size != HAND_SIZE-n+1
    for value in value_array
      cards_of_value = get_cards_of_value(value, hand)
      return cards_of_value if cards_of_value.size == n
    end
    return nil
  end

  def self.process_straight(hand)
    non_sequence = 0 # Since is impossible to do a full circle
    for i in 0...HAND_SIZE
      non_sequence += 1 if get_next_value(hand[i].value) != hand[(i+1)%5].value
      return nil if non_sequence >= 2
    end
    return hand
  end

  # Get the next card value defined in VALUE_SEQUENCE
  def self.get_next_value(value)
    return VALUE_SEQUENCE[(VALUE_SEQUENCE.index(value) + 1) % VALUE_SEQUENCE.size]
  end

  def self.validate_deck(deck)
    if deck.find_all { |card| card.value==JOKER }.size > 2
      raise "Due to algorithm limitations, no more than 2 jokers are allowed"
    end
  end

  class Card
    attr_reader :value
    attr_reader :suit

    def initialize(value, suit=0)
      @value = value
      @suit = suit
    end

    def comparation_number
      return @value*10+@suit
    end

    def to_s
      return [@value,@suit].to_s
    end

    def inspect
      return to_s
    end

    def <=>(other)
      return comparation_number <=> other.comparation_number
    end
    
    def ==(other)
      return (self<=>other) == 0
    end
  end

  class Combination
    attr_reader :name
    attr_reader :bonus
    attr_reader :rule_proc # Proc who returns the cards with the combination

    def initialize(name, bonus, rule_proc)
      @name = name
      @bonus = bonus
      @rule_proc = rule_proc
    end
  end

  class CombinationFound
    attr_reader :combination
    attr_reader :card_array

    def initialize(combination, card_array)
      @combination = combination
      @card_array = card_array
    end

    def to_short_s # For debug
      return "#{@combination.name}: #{@card_array}"
    end
  end 

  class Cursor
    attr_reader   :index
    attr_accessor :block_zero

    LIMIT = HAND_SIZE

    def index=(value)
      if @block_zero
        @index = (LIMIT-1 + value-1) % (LIMIT-1) + 1
      else 
        @index = (LIMIT + value) % LIMIT
      end
      refresh
    end

    def visible=(value)
      @sprite.visible = value
    end

    # Uses card sprite x + x_bonus as x
    def initialize(x, x_gain, y, viewport)
      @x = x
      @x_gain = x_gain
      @sprite = IconSprite.new(0,0,viewport)
      @sprite.setBitmap(Bridge.sel_arrow_white_path)
      @sprite.y = y
      @index = 0
      self.visible = false
      refresh
    end
    
    def move_left;  self.index-=1; end  
    def move_right; self.index+=1; end  

    def update
      @sprite.update
    end

    def dispose
      @sprite.dispose
    end

    def refresh
      @sprite.x = @x + @x_gain*self.index
    end

    def reset_index
      self.index = @block_zero ? 1 : 0
    end
  end

  # Class for Combination Window.
  # The text of the windows isn't used, but it creates a BitmapSprite and 
  # use the text over.
  class Window_Combination < Window_AdvancedTextPokemon
    def initialize(combination_array, only_display_text, viewport)
      super()
      self.viewport = viewport
      @only_display_text = only_display_text
      @combination_array = combination_array
      @wager = 1
      @overlay_sprite = generate_overlay(viewport)
      self.visible = !@only_display_text
    end

    def setup_measures(width, height_without_border, lines)
      self.width = width
      self.height = height_without_border + self.borderY
      @lines = lines
      @columns = (@combination_array.size/@lines.to_f).ceil
      @x_gain = self.column_width/2 - 16
      @y_center = self.y + self.height/2 - 8
    end

    def column_width
      return self.width/@columns
    end

    def color=(value)
      super(value) if !@only_display_text
      @overlay_sprite.color=value
    end

    def text_colors(highlight)
      if highlight
        return [Color.new(248, 152,  24), MessageConfig::LIGHT_TEXT_SHADOW_COLOR] if @only_display_text
        return [Color.new(232, 32, 16), Color.new(248, 168, 184)]
      end
      return [MessageConfig::LIGHT_TEXT_MAIN_COLOR, MessageConfig::LIGHT_TEXT_SHADOW_COLOR] if @only_display_text
      return getDefaultTextColors(self.windowskin)
    end
    
    def update
      super
      @overlay_sprite.update
    end

    def dispose
      super
      @overlay_sprite.dispose
    end

    def generate_overlay(viewport)
      ret = BitmapSprite.new(Graphics.width, Graphics.height, viewport)
      ret.z = self.z+1
      pbSetSmallFont(ret.bitmap)
      return ret
    end

    def refresh_wager(value)
      @wager = value
      clear_and_draw
    end

    def clear_and_draw(combination_to_highlight=nil)
      @overlay_sprite.bitmap.clear
      Bridge.draw_text_positions(@overlay_sprite.bitmap, generate_text_positions(combination_to_highlight))
    end

    def generate_text_positions(combination_to_highlight)
      ret = []
      for column in 0...@columns
        for line in 0...@lines
          combination = @combination_array[@lines*column + line]
          ret += generate_line_text_positions(
            combination, 
            self.x + self.column_width*(column*2+1)/2, 
            (line-@lines/2)*24 + @y_center,
            text_colors(combination==combination_to_highlight)
          )
        end
      end
      return ret
    end

    def generate_line_text_positions(combination, x_center, y, text_colors)
      return [] if !combination
      return [
        [combination.name, x_center - @x_gain, y, false, text_colors[0], text_colors[1]],
        [Bridge.to_s_formatted(@wager*combination.bonus), x_center + @x_gain, y, true, text_colors[0], text_colors[1]]
      ]
    end
  end

  class Scene
    attr_reader   :hand_hold # Bool array with the positions marked as hold

    DISTANCE_BETWEEN_CARDS = 92

    def start(screen, combination_array)
      @screen = screen
      @scene_time = 0
      @sprites = {} 
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 99999
      @hand = []
      create_card_source("Graphics/UI/Video Poker/cards")
      @sprites["background"] = AnimatedPlane.new(@viewport)
      @sprites["background"].setBitmap("Graphics/UI/Video Poker/background")
      create_windows(combination_array)
      create_card_sprites
      @cursor = Cursor.new(
        @sprites["card0"].x - @card_center_x_bonus - 38, 
        DISTANCE_BETWEEN_CARDS, @sprites["card0"].y + @card_height + 2, 
        @viewport
      )
      @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
      pbSetSystemFont(@sprites["overlay"].bitmap)
      @sprites["overlay"].visible = false
      @highlight_combination = false
      self.message_visible = false if HIDE_MESSAGE_WHEN_SELECTING
      reset_hold
      refresh
      pbFadeInAndShow(@sprites) { update }
      wait(0.7) if HIDE_MESSAGE_WHEN_SELECTING
    end

    def create_windows(combination_array)
      @sprites["combination_window"] = Window_Combination.new(combination_array, !COMBINATIONS_IN_A_WINDOW, @viewport)
      @sprites["combination_window"].setup_measures(Graphics.width - 112, 32*4, 5)
      @sprites["coin_window"]=Window_AdvancedTextPokemon.new
      @sprites["coin_window"].viewport = @viewport
      @sprites["coin_window"].x = @sprites["combination_window"].width
      @sprites["coin_window"].width = Graphics.width - @sprites["combination_window"].width
      @sprites["coin_window"].height = @sprites["combination_window"].height
      @sprites["message_window"] = Bridge.create_message_window(@viewport)
      # Remove below line to make text box going letter by letter
      @sprites["message_window"].letterbyletter = false
      pbSetSystemFont(@sprites["message_window"].contents)
    end

    def create_card_sprites
      for i in 0...HAND_SIZE
        @sprites["card_blank#{i}"] = BitmapSprite.new(@card_width, @card_height, @viewport)
        @sprites["card#{i}"] = BitmapSprite.new(@card_width, @card_height, @viewport)
        @sprites["card_back#{i}"] = BitmapSprite.new(@card_width, @card_height, @viewport)
        @sprites["card#{i}"].x = (i-2)*DISTANCE_BETWEEN_CARDS + @card_center_x_bonus + Graphics.width/2 
        @sprites["card#{i}"].y = 208 + @card_center_y_bonus
        @sprites["card#{i}"].y += 62 if HIDE_MESSAGE_WHEN_SELECTING
        @sprites["card_blank#{i}"].x = @sprites["card#{i}"].x
        @sprites["card_blank#{i}"].y = @sprites["card#{i}"].y
        @sprites["card_back#{i}"].x = @sprites["card#{i}"].x
        @sprites["card_back#{i}"].y = @sprites["card#{i}"].y
        @sprites["card_blank#{i}"].bitmap.blt(0, 0, @card_source.bitmap, get_card_blank_rect)
        @sprites["card_back#{i}"].bitmap.blt(0, 0, @card_source.bitmap, get_card_back_rect)
      end
    end

    def create_card_source(path)
      @card_source = AnimatedBitmap.new(path)
      if @card_source.bitmap.width % 4 != 0
        raise "The width of card's spritesheet must be divisible by 4! Current width: #{@card_source.bitmap.width}."
      end
      if @card_source.bitmap.height % (HIGHEST_CARD+1) != 0
        raise "The height of card's spritesheet must be divisible by #{HIGHEST_CARD+1}! Current height: #{@card_source.bitmap.height}."
      end
      @card_width = @card_source.bitmap.width/4
      @card_height = @card_source.bitmap.height/(HIGHEST_CARD+1)
      # +1 to correctly center cards with odd meansures
      @card_center_x_bonus = -@card_width/2
      @card_center_x_bonus+= 1 if @card_center_x_bonus%2!=0
      @card_center_y_bonus = -@card_height/2
      @card_center_y_bonus+= 1 if @card_center_y_bonus%2!=0
    end

    def activate_select_mode(in_double_or_nothing)
      reset_hold
      @sprites["overlay"].visible = true
      @cursor.visible = true
      @cursor.block_zero = in_double_or_nothing
      @cursor.reset_index
      @highlight_combination = ALWAYS_HIGHLIGHT_COMBINATION if !in_double_or_nothing
      refresh_select_message
      refresh
    end

    def deactivate_select_mode
      @cursor.visible = false
      @sprites["overlay"].visible = false
    end

    def refresh_select_message
      @sprites["message_window"].text = self.message_in_select_mode
    end

    def message_in_select_mode
      if @screen.in_double_or_nothing?
        return _INTL("Select a card.") if ASK_IN_DOUBLE_OR_NOTHING
        return _INTL("Select a higher card than this from the 4 cards.")
      end
      return _INTL("Choose cards.\nPress Cancel when ready.")
    end

    def message_visible=(value)
      @sprites["message_window"].visible = value
    end

    def reset_hold
      @hand_hold = Array.new(HAND_SIZE){ false }
    end

    def refresh
      @sprites["combination_window"].clear_and_draw(
        (@screen.combination_found && @highlight_combination) ? @screen.combination_found.combination : nil
      )
      refresh_cards
      refresh_card_labels
      refresh_coin_window
    end

    def refresh_cards
      for i in 0...HAND_SIZE
        @sprites["card_back#{i}"].visible = !@hand[i]
        @sprites["card#{i}"].visible = !@sprites["card_back#{i}"].visible
        next if !@sprites["card#{i}"].visible
        @sprites["card#{i}"].visible = true
        @sprites["card#{i}"].bitmap.clear
        @sprites["card#{i}"].bitmap.blt(0, 0, @card_source.bitmap, get_card_rect(@hand[i]))
      end
    end

    def refresh_card_labels
      @sprites["overlay"].bitmap.clear
      Bridge.draw_text_positions(@sprites["overlay"].bitmap, generate_card_label_text_positions)
    end

    def generate_card_label_text_positions
      ret=[]
      for i in 0...HAND_SIZE
        ret.push([
          current_label_text(i), 
          @sprites["card#{i}"].x - @card_center_x_bonus, 
          @sprites["card#{i}"].y + @card_height + 8,
          2, Color.new(248,248,248), Color.new(0,0,0)
        ])
      end
      return ret
    end

    def current_label_text(index)
      if @screen.in_double_or_nothing?
        return index==0 ? "" : _INTL("This") 
      end
      return @hand_hold[index] ? _INTL("Hold") : _INTL("Draw")
    end

    def refresh_coin_window
      @sprites["coin_window"].text = _INTL("Coins:\n<ar>{1}</ar>", Bridge.to_s_formatted(player_coins))+"\n"
      if @screen.round_earnings
        @sprites["coin_window"].text += _INTL("Won:\n<ar>{1}</ar>", Bridge.to_s_formatted(@screen.round_earnings))
      else
        @sprites["coin_window"].text += _INTL("Bet:\n<ar>{1}</ar>", Bridge.to_s_formatted(@screen.wager))
      end
    end

    def player_coins
      ret = @screen.coins
      ret -= @screen.wager if !@screen.entry_cost_was_paid?
      return ret
    end

    def get_card_rect(card)
      ret = Rect.new((card.suit-1)*@card_width, (card.value-1)*@card_height, @card_width, @card_height)
      if card.value == JOKER
        ret.x = (card.suit==2 ? 1 : 0)*@card_width
        ret.y = HIGHEST_CARD*@card_height
      end
      return ret
    end

    def get_card_blank_rect
      return Rect.new(2*@card_width, HIGHEST_CARD*@card_height, @card_width, @card_height)
    end

    def get_card_back_rect
      return Rect.new(3*@card_width, HIGHEST_CARD*@card_height, @card_width, @card_height)
    end

    def stop_cards_flashing
      for i in 0...HAND_SIZE
        @sprites["card#{i}"].visible = true
      end
    end

    def show_result(earnings)
      @highlight_combination = true
      refresh
      if earnings == 0
        @sprites["message_window"].text = _INTL("What a shame!\nYou lost.")
      else
        @sprites["message_window"].text = _INTL("Congratulations!\nYou've won {1} coins.", earnings)
        play_victory_me(@screen.combination_found.combination.bonus >= MIN_BONUS_FOR_BIG_ME)
      end
    end

    def show_result_as_draw
      @sprites["message_window"].text = _INTL("A draw! Try again.")
    end

    def play_victory_me(big)
      if big
        pbMEPlay(Bridge.audio_name("Slots big win"))
      else
        pbMEPlay(Bridge.audio_name("Slots win"))
      end
    end

    def update_all
      Graphics.update
      Input.update
      self.update
    end

    def wait(seconds=0)
      target_time = @scene_time + seconds
      while @scene_time < target_time
        update_all
      end
    end

    def flip_animation(new_hand, flip_back, flip_array)
      for i in 0...HAND_SIZE
        next if flip_array[i]==false
        @hand[i] = new_hand[i]
        if !flip_back
          # To change flip sound effect, change 
          # below line for something like: pbSEPlay("GUI party switch")
          pbSEPlay(Bridge.audio_name("Voltorb Flip tile"))
        end
        refresh_cards
        wait(flip_back ? 0.08 : 0.25)
      end
    end

    def flip_hand_animation(new_hand, flip_array=[])
      flip_animation(new_hand, false, flip_array)
    end

    def flip_back_hand_animation(flip_array=[])
      flip_animation([], true, flip_array)
    end

    def confirm_wager
      refresh
      @sprites["message_window"].text = ""
      ret = Bridge.confirm_message(_INTL("The minimum wanger is {1}. Do you want to play?", @screen.min_wager)){
        update
      }
      wait(0.2) # To avoid SE overlapping
      ret ? pbSEPlay(Bridge.audio_name("Slots coin")) : pbPlayCancelSE
      return ret
    end

    # Return if selected successfully
    def select_wager_loop
      refresh
      @sprites["message_window"].text = _INTL("Select your wager.\nPress Cancel to exit.")
      loop do
        update_all
        if Input.trigger?(Input::C)
          pbSEPlay(Bridge.audio_name("Slots coin"))
          return true
        end
        if Input.trigger?(Input::B)
          pbPlayCancelSE
          return false
        end
        # Uncommend above code to Input::A also confirm cards
        # if Input.trigger?(Input::A)
        #  break
        # end
        on_press_in_select_wager(-1 ) if Input.repeat?(Input::DOWN)
        on_press_in_select_wager( 1 ) if Input.repeat?(Input::UP)
        on_press_in_select_wager(-10) if Input.repeat?(Input::LEFT)
        on_press_in_select_wager( 10) if Input.repeat?(Input::RIGHT)
      end
    end

    def confirm_double_or_nothing(number, current_earnings)
      @sprites["message_window"].text = ""
      return Bridge.confirm_message(
        _INTL("If you win, you will get {1} coins. Will you try double or nothing round {2}?", current_earnings*2, number)
      ){ update }
    end

    def ask_higher
      @sprites["message_window"].text = ""
      return Bridge.message(
        _INTL("Try to guess if this card will be higher or lower."), [_INTL("Higher"),_INTL("Lower")]
      ){ update } == 0
    end

    def on_press_in_select_wager(gain)
      try_change_select_wager([[(@screen.wager+gain), @screen.min_wager].max, @screen.max_wager].min)
    end

    def try_change_select_wager(new_wager)
      return if new_wager==@screen.wager
      @screen.wager=new_wager
      refresh_coin_window
      @sprites["combination_window"].refresh_wager(@screen.wager)
      pbPlayCursorSE
    end

    def cursor_loop
      activate_select_mode(false)
      loop do
        update_all
        update_cards_flashing
        if Input.trigger?(Input::C)
          @hand_hold[@cursor.index] = !@hand_hold[@cursor.index]
          refresh_card_labels
          pbPlayDecisionSE
        end
        if Input.trigger?(Input::B)
          pbPlayCancelSE
          break
        end
        # Uncommend the above code to Input::A also confirm cards
        # if Input.trigger?(Input::A)
        #  break
        # end
        if Input.trigger?(Input::LEFT)
          pbPlayCursorSE
          @cursor.move_left
        end 
        if Input.trigger?(Input::RIGHT)
          pbPlayCursorSE
          @cursor.move_right
        end
      end
      stop_cards_flashing
      deactivate_select_mode
    end

    # Return the selected card index
    def double_or_nothing_cursor_select
      ret = nil
      activate_select_mode(true)
      loop do
        update_all
        if Input.trigger?(Input::C)
          pbPlayDecisionSE
          ret = @cursor.index
          break
        end
        if Input.trigger?(Input::LEFT)
          pbPlayCursorSE
          @cursor.move_left
        end 
        if Input.trigger?(Input::RIGHT)
          pbPlayCursorSE
          @cursor.move_right
        end
      end
      deactivate_select_mode
      return ret
    end

    def confirm_loop
      loop do
        update_all
        if Input.trigger?(Input::C)
          pbPlayCursorSE
          break
        end
        if Input.trigger?(Input::B)
          pbPlayCancelSE
          break
        end
      end
    end

    def update_cards_flashing
      return if !ALWAYS_HIGHLIGHT_COMBINATION || !FLASH_CARDS
      for i in 0...HAND_SIZE
        next if !@screen.hand_card_in_combination?(i)
        next if @sprites["card#{i}"].visible == ((@scene_time*8).floor % 12 != 0)
        @sprites["card#{i}"].visible = !@sprites["card#{i}"].visible
      end
    end

    def update
      @scene_time += Bridge.delta 
      pbUpdateSpriteHash(@sprites)
      @cursor.update
    end

    def finish
      @cursor.visible = false
      pbFadeOutAndHide(@sprites) { update }
      pbDisposeMessageWindow(@sprites["message_window"])
      pbDisposeSpriteHash(@sprites)
      @cursor.dispose
      @card_source.dispose
      @viewport.dispose
    end
  end

  class Screen
    attr_accessor :wager
    attr_reader   :min_wager
    attr_reader   :round_earnings # in coins
    attr_reader   :combination_found

    # DON = Double or Nothing
    DON_WON = 1
    DON_LOST = -1
    DON_DRAW = 0

    def initialize(scene)
      @scene=scene
      @combination_array = VideoPoker.generate_combination_array
      @wager = 1
      @valid_card_array = get_valid_card_array(VideoPoker.generate_deck)
    end

    def max_wager
      return [@max_wager, Bridge.coins].min
    end

    def entry_cost_was_paid?
      return !@hand.empty?
    end

    def coins
      return Bridge.coins
    end

    # Return if the hand index is in current combination
    def hand_card_in_combination?(index)
      return @combination_found && (@hand[index].value==JOKER || @combination_found.card_array.include?(@hand[index]))
    end

    # Reset values. Doesn't reset wager.
    def reset_values
      @hand = []
      @combination_found = nil
      @round_earnings = nil
      @double_or_nothing_round = 0
      @last_don_result = nil
      @wager = [[@wager, self.min_wager].max, self.max_wager].min
    end

    def in_double_or_nothing?
      return @double_or_nothing_round > 0
    end

    def play(min_wager, max_wager)
      @min_wager = min_wager
      @max_wager = max_wager
      reset_values
      @scene.start(self, @combination_array)
      main_loop
      @scene.finish
    end

    def main_loop
      loop do
        reset_values
        @scene.message_visible = true
        break if !select_wager
        Bridge.coins-=@wager
        @scene.message_visible = false if HIDE_MESSAGE_WHEN_SELECTING
        @scene.wait(0.2)
        initialize_hand
        @scene.flip_hand_animation(@hand)
        @scene.cursor_loop
        finish_round
        double_or_nothing_loop
        Bridge.coins = [Bridge.max_coins, Bridge.coins+@round_earnings].min
      end
    end

    # Select wager, or confirm if min and max are equals.
    # Returns false if canceled.
    def select_wager
      return @min_wager==@max_wager ? @scene.confirm_wager : @scene.select_wager_loop
    end

    def initialize_hand
      @deck = VideoPoker.generate_deck.shuffle
      @hand = Bridge.pop(@deck, 5)
      @sorted_combination_array = @combination_array.clone.sort_by{|combination| combination.bonus}.reverse
      @combination_found = check_combinations(@sorted_combination_array, @hand)
    end

    # Show the replaced cards and end round
    def finish_round
      replace_hand_cards
      @scene.flip_back_hand_animation(reverse_bool_array(@scene.hand_hold))
      @scene.flip_hand_animation(@hand, reverse_bool_array(@scene.hand_hold))
      @scene.reset_hold
      @combination_found = check_combinations(@sorted_combination_array, @hand)
      @round_earnings = @combination_found ? @combination_found.combination.bonus*@wager : 0
      @scene.show_result(@round_earnings)
      if HIDE_MESSAGE_WHEN_SELECTING
        @scene.confirm_loop
        @scene.message_visible = true
      end
      @scene.confirm_loop
      @scene.message_visible = false if HIDE_MESSAGE_WHEN_SELECTING
      @scene.flip_back_hand_animation
    end

    # Replace non-hold hand cards
    def replace_hand_cards
      for i in 0...HAND_SIZE
        next if @scene.hand_hold[i]
        @hand[i] = @deck.pop
      end
    end

    def change_single_hand_card(hand, index, new_card)
      ret = hand.clone
      ret[index] = new_card
      return ret
    end

    def reverse_bool_array(array)
      return array.map{|v| !v}
    end

    # Create an array with only one position as true
    def create_single_animation_parameter(index)
      ret = Array.new(5){false}
      ret[index] = true
      return ret
    end

    def double_or_nothing_loop
      @double_or_nothing_round = 1
      while can_play_double_or_nothing?
        if DON_DRAW != @last_don_result && !@scene.confirm_double_or_nothing(@double_or_nothing_round, @round_earnings)
          break
        end
        finish_double_or_nothing_round(select_double_or_nothing_card)
      end
    end

    # Select double or nothing card. Returns the cursor index.
    def select_double_or_nothing_card
      if HIDE_MESSAGE_WHEN_SELECTING && !ASK_IN_DOUBLE_OR_NOTHING
        @scene.message_visible = true
        @scene.refresh_select_message
        @scene.confirm_loop
      end
      @scene.message_visible = false if HIDE_MESSAGE_WHEN_SELECTING
      @deck = VideoPoker.generate_deck.shuffle
      @hand = Bridge.pop(@deck, 5)
      @scene.flip_hand_animation(@hand, create_single_animation_parameter(0))
      ret = @scene.double_or_nothing_cursor_select
      @last_don_result = double_or_nothing_compare(
        @hand[0], @hand[ret], !ASK_IN_DOUBLE_OR_NOTHING || @scene.ask_higher
      )
      return ret
    end

    def finish_double_or_nothing_round(cursor_index)
      @scene.flip_hand_animation(@hand, create_single_animation_parameter(cursor_index))
      case @last_don_result
      when DON_WON
        @round_earnings=0
      when DON_LOST
        @round_earnings*=2
        @double_or_nothing_round+=1
      end
      @last_don_result==DON_DRAW ? @scene.show_result_as_draw : @scene.show_result(@round_earnings)
      if HIDE_MESSAGE_WHEN_SELECTING
        @scene.confirm_loop
        @scene.message_visible = true
      end
      @scene.confirm_loop
      @scene.flip_back_hand_animation
    end

    def can_play_double_or_nothing?
      return (
        @round_earnings > 0 &&
        @round_earnings*2 <= DOUBLE_OR_NOTHING_COIN_LIMIT && 
        @double_or_nothing_round <= DOUBLE_OR_NOTHING_TRIES_LIMIT &&
        Bridge.max_coins > Bridge.coins+@round_earnings
      )
    end

    # Compare sequence in bigger or nothing.
    # Returns +1 fifr won, -1 for lost and 0 for draw.
    # If DOUBLE_OR_NOTHING doesn't include the joker, treat joker as 
    # most advantageous for the player.
    def double_or_nothing_compare(card_a, card_b, ask_higher)
      if !DOUBLE_OR_NOTHING.include?(JOKER) && [card_a.value,card_b.value].include?(JOKER)
        return [card_a.value,card_b.value].include?(DOUBLE_OR_NOTHING[ask_higher ? -1 : 0]) ? DON_DRAW : DON_WON
      end
      ret = DOUBLE_OR_NOTHING.index(card_a.value) <=> DOUBLE_OR_NOTHING.index(card_b.value)
      ret*=-1 if !ask_higher
      return ret
    end

    def check_combinations(combination_array, original_hand)
      possible_hand_array = get_possible_hand_array(original_hand.clone)
      for combination in combination_array
        for hand in possible_hand_array
          card_array = combination.rule_proc.call(hand, original_hand)
          next if !card_array
          return CombinationFound.new(combination, card_array)
        end
      end
      return nil
    end

    def get_valid_card_array(card_array)
      ret = []
      for card in card_array
        next if card.value==JOKER
        ret.push(card)
      end
      return ret
    end

    def get_possible_hand_array(hand)
      ret = []
      for i in 0...hand.size
        next if hand[i].value != JOKER
        for valid_card in @valid_card_array
          ret += get_possible_hand_array(change_single_hand_card(hand, i, valid_card))
        end
      end
      ret.push(hand.sort) if ret.empty?
      return ret
    end
  end

  # Essentials multiversion layer
  module Bridge
    @@audioNameHash = nil
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

    def delta
      return 0.025 if MAJOR_VERSION < 21
      return Graphics.delta
    end
    
    def pop(array, number=1)
      if MAJOR_VERSION < 19
        ret = []
        number.times do
          ret.push(array.pop)
        end
        return ret
      end
      return array.pop(number)
    end

    def to_s_formatted(value)
      return value.to_s if MAJOR_VERSION < 18
      return value.to_s_formatted
    end

    def message(string, commands=nil, &block)
      return Kernel.pbMessage(string, commands, &block) if MAJOR_VERSION < 20
      return pbMessage(string, commands, &block)
    end

    def confirm_message(string, &block)
      return Kernel.pbConfirmMessage(string, &block) if MAJOR_VERSION < 20
      return pbConfirmMessage(string, &block)
    end

    def draw_text_positions(bitmap,textpos)
      if MAJOR_VERSION < 20
        for singleTextPos in textpos
          singleTextPos[2] -= MAJOR_VERSION==19 ? 12 : 6
        end
      end
      return pbDrawTextPositions(bitmap,textpos)
    end

    def create_message_window(viewport)
      return Kernel.pbCreateMessageWindow(viewport) if MAJOR_VERSION < 20
      return pbCreateMessageWindow(viewport)
    end

    def sel_arrow_white_path
      return _INTL("Graphics/Pictures/selarrowwhite") if MAJOR_VERSION < 17
      return _INTL("Graphics/Pictures/selarrow_white") if MAJOR_VERSION < 21
      return _INTL("Graphics/UI/sel_arrow_white")
    end
    
    def coin_holder
      return case MAJOR_VERSION
        when 0..18; $PokemonGlobal
        when 19;    $Trainer
        else        $player
      end
    end

    def coins
      return coin_holder.coins
    end

    def coins=(value)
      coin_holder.coins = value
    end

    def max_coins
      return case MAJOR_VERSION
        when 0..17; MAXCOINS
        when 18;    MAX_COINS
        else        Settings::MAX_COINS
      end
    end

    def has_coin_case?
      return case MAJOR_VERSION
        when 0..18; $PokemonBag.pbQuantity(PBItems::COINCASE) > 0
        when 19;    $PokemonBag.pbHasItem?(:COINCASE)
        else        $bag.has?(:COINCASE)
      end
    end

    def audio_name(baseName)
      if !@@audioNameHash
        if MAJOR_VERSION < 17
          @@audioNameHash = {
            "Slots coin"       => "SlotsCoin"  ,
            "Slots win"        => "SlotsWin"   ,
            "Slots big win"    => "SlotsBigWin",
            "Voltorb Flip tile"=> "VoltorbFlipTile"
          }
        else
          @@audioNameHash = {}
        end
      end
      return @@audioNameHash.fetch(baseName, baseName)  
    end
  end

  def self.play(min_wager=1, max_wager=nil)
    if !Bridge.has_coin_case?
      Bridge.message(_INTL("It's a Poker table."))
    elsif Bridge.coins<min_wager
      Bridge.message(_INTL("You don't have enough Coins to play!"))
    elsif Bridge.coins==Bridge.max_coins
      Bridge.message(_INTL("Your Coin Case is full!"))  
    else
      pbFadeOutIn(99999){     
        scene=Scene.new
        screen=Screen.new(scene)
        screen.play(min_wager, max_wager || min_wager)
      }
    end
  end
end