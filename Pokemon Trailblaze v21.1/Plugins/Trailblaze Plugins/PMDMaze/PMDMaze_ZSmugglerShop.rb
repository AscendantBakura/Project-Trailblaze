#===============================================================================
# PMDMaze - Animated portraits and the smuggler shop scene (Trailblaze)
#   * PMDDungeon::Portrait shows a looping animated trainer front
#     (DBK_010 TrainerBitmapWrapper) and optionally an animated Pokemon front
#     (DBK_009 PokemonSprite) above the message box while a dialogue runs.
#   * PMDDungeon::SmugglerShop is the layered smuggler scene built from
#     Graphics/UI/overlayUI/Shop Sprite: background, shopkeeper, Eyes/ and
#     Mouths/ layers with blinking, talking and expressions.
#   Missing or non-animated art is recorded in PMDDungeon::Portrait.missing /
#   SmugglerShop.missing_files and printed to the console; it is never
#   silently replaced by another graphic.
#===============================================================================
module PMDDungeon
  module Portrait
    module_function

    def missing
      @missing ||= []
      return @missing
    end

    def note_missing(text)
      return if missing.include?(text)
      missing << text
      echoln("[PMDMaze] #{text}") if defined?(echoln)
    end

    def open(tr_type, pokemon = nil)
      session = Session.new(tr_type, pokemon)
      begin
        return yield(session)
      ensure
        session.dispose
      end
    end

    # One-line dialogue with an animated portrait.
    def talk(tr_type, text, pokemon = nil)
      return open(tr_type, pokemon) { |pt| pt.say(text) }
    end

    class Session
      attr_reader :trainer_frames

      def initialize(tr_type, pokemon = nil)
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = 99_998
        @trainer_frames = 0
        setup_trainer(tr_type) if tr_type
        setup_pokemon(pokemon) if pokemon
      end

      def setup_trainer(tr_type)
        if !GameData::TrainerType.exists?(tr_type)
          Portrait.note_missing("Trainer type #{tr_type} is not defined; no portrait shown.")
          return
        end
        file = GameData::TrainerType.front_sprite_filename(tr_type)
        if !file
          Portrait.note_missing("Graphics/Trainers/#{tr_type} is missing; no portrait shown.")
          return
        end
        @wrapper = GameData::TrainerType.front_sprite_bitmap(tr_type)
        @trainer_frames = @wrapper.length
        Portrait.note_missing("#{file} has a single frame (not animated).") if @trainer_frames <= 1
        @trainer = Sprite.new(@viewport)
        @trainer.bitmap = @wrapper.bitmap
        zoom = (@wrapper.height <= 100) ? 2 : 1
        @trainer.zoom_x = @trainer.zoom_y = zoom
        @trainer.ox = @wrapper.width / 2
        @trainer.oy = @wrapper.height
        @trainer.x = Graphics.width - 100
        @trainer.y = Graphics.height - 96
      end

      def setup_pokemon(pokemon)
        pokemon = Pokemon.new(pokemon, 5) if pokemon.is_a?(Symbol)
        return if !pokemon
        @pokemon = PokemonSprite.new(@viewport)
        @pokemon.setOffset(PictureOrigin::BOTTOM)
        @pokemon.setPokemonBitmap(pokemon)
        @pokemon.x = 104
        @pokemon.y = Graphics.height - 96
      end

      def update
        if @wrapper && @trainer && !@trainer.disposed?
          @wrapper.update
          @trainer.bitmap = @wrapper.bitmap
        end
        @pokemon.update if @pokemon && !@pokemon.disposed?
      end

      def say(text, commands = nil, cancel = 0)
        return pbMessage(text, commands, cancel) { update }
      end

      def confirm(text, choices = nil)
        return pbConfirmMessage(text) { update } if !choices || choices == [_INTL("Yes"), _INTL("No")]
        return pbMessage(text, choices, 2) { update } == 0
      end

      def dispose
        @trainer&.dispose
        @wrapper&.dispose
        @pokemon&.dispose
        @viewport&.dispose
      end
    end
  end

  module SmugglerShop
    EYES   = %w[annoyed closed default glee shock squint unamused]
    MOUTHS = %w[annoyed frown1 frown2 grin smile talk1 talk2]
    EXPRESSIONS = {
      neutral: ["default", "smile"],
      greet:   ["default", "grin"],
      pitch:   ["squint", "grin"],
      happy:   ["glee", "smile"],
      broke:   ["annoyed", "frown1"],
      full:    ["shock", "frown2"],
      soldout: ["unamused", "frown2"],
      leave:   ["squint", "smile"]
    }
    TALK_FRAMES_PER_CHAR = 2
    MOUTH_SWAP_SECONDS   = 0.12
    BLINK_SECONDS        = 0.12

    module_function

    def cfg
      return PMDDungeon::FeatureConfig
    end

    def base_dir
      return PMDDungeon::DataStore.setting(:FeatureConfig, :SMUGGLER_SHOP_ART)
    end

    def layer_paths
      paths = ["#{base_dir}/background", "#{base_dir}/shopkeeper"]
      EYES.each { |e| paths << "#{base_dir}/Eyes/#{e}_eyes" }
      MOUTHS.each { |m| paths << "#{base_dir}/Mouths/#{m}_mouth" }
      return paths
    end

    def missing_files
      return layer_paths.reject { |p| pbResolveBitmap(p) }
    end

    def open(stock)
      scene = Scene.new
      begin
        scene.run(stock)
      ensure
        scene.dispose
      end
    end

    class Scene
      attr_reader :expression

      def initialize
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = 99_998
        missing = SmugglerShop.missing_files
        if !missing.empty?
          missing.each { |m| Portrait.note_missing("Smuggler art missing: #{m}.png") }
          pbMessage(_INTL("[Missing smuggler art: {1}]", missing.join(", "))) if $DEBUG
        end
        @sprites = {}
        @sprites[:bg]     = layer("background", 0)
        @sprites[:keeper] = layer("shopkeeper", 1)
        @sprites[:eyes]   = layer(nil, 2)
        @sprites[:mouth]  = layer(nil, 3)
        @eyes_bmp  = {}
        @mouth_bmp = {}
        EYES.each { |e| @eyes_bmp[e] = load("Eyes/#{e}_eyes") }
        MOUTHS.each { |m| @mouth_bmp[m] = load("Mouths/#{m}_mouth") }
        @next_blink = System.uptime + 3 + rand * 2
        @blink_until = 0
        @talk_until = 0
        set_expression(:neutral)
      end

      def load(name)
        path = "#{SmugglerShop.base_dir}/#{name}"
        return pbResolveBitmap(path) ? RPG::Cache.load_bitmap("", path) : nil
      end

      def layer(name, z)
        s = Sprite.new(@viewport)
        s.z = z
        s.bitmap = load(name) if name
        return s
      end

      def set_expression(expr)
        @expression = expr
        @eyes, @mouth = EXPRESSIONS[expr] || EXPRESSIONS[:neutral]
        refresh_face
      end

      def eyes_frame
        return "closed" if System.uptime < @blink_until
        return @eyes
      end

      def mouth_frame
        return @mouth if System.uptime >= @talk_until
        return ((System.uptime / MOUTH_SWAP_SECONDS).floor.even?) ? "talk1" : "talk2"
      end

      def refresh_face
        @sprites[:eyes].bitmap = @eyes_bmp[eyes_frame]
        @sprites[:mouth].bitmap = @mouth_bmp[mouth_frame]
      end

      def update
        now = System.uptime
        if now >= @next_blink
          @blink_until = now + BLINK_SECONDS
          @next_blink = now + 3 + rand * 2
        end
        refresh_face
      end

      def say(expr, text, commands = nil, cancel = 0)
        set_expression(expr)
        chars = text.to_s.gsub(/\\[a-z]+\[[^\]]*\]|\\./i, "").length
        @talk_until = System.uptime + (chars * TALK_FRAMES_PER_CHAR / 60.0)
        ret = pbMessage(text, commands, cancel) { update }
        @talk_until = 0
        refresh_face
        return ret
      end

      def confirm(expr, text)
        set_expression(expr)
        return pbConfirmMessage(text) { update }
      end

      def run(stock)
        f = PMDDungeon::Features
        say(:greet, _INTL("Psst... Looking for something you won't find in town? Prices are what they are."))
        loop do
          avail = stock.select { |_, q| q > 0 }.keys
          if avail.empty?
            say(:soldout, _INTL("I'm all sold out. Come back next run."))
            break
          end
          cmds = avail.map { |i| _INTL("{1} ${2} (x{3})", GameData::Item.get(i).name, f.smuggler_price(i).to_s_formatted, stock[i]) }
          cmds << _INTL("Leave")
          idx = say(:pitch, _INTL("Money: ${1}", $player.money.to_s_formatted), cmds, cmds.length)
          break if idx < 0 || idx >= avail.length
          item = avail[idx]
          price = f.smuggler_price(item)
          if $player.money < price
            say(:broke, _INTL("No money, no deal."))
            next
          end
          if !$bag.can_add?(item)
            say(:full, _INTL("Your bag's stuffed! Make some room first."))
            next
          end
          next if !confirm(:pitch, _INTL("{1} for ${2}?", GameData::Item.get(item).name, price.to_s_formatted))
          $player.money -= price
          $bag.add(item)
          stock[item] -= 1
          say(:happy, _INTL("Pleasure doing business."))
        end
        say(:leave, _INTL("You didn't see me here."))
      end

      def dispose
        @sprites.each_value(&:dispose)
        @viewport.dispose
      end
    end
  end
end
