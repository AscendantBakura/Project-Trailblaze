#==============================================================================#
#             Carmaniac's (AKA Lostsoulsdev) Speech Bubble                     #
#                                 V2.2.0                                       #
#------------------------------------------------------------------------------#
#                           For Essentials V21.1                               #
#                 Developed by Carmaniac (AKA Lostsoulsdev)                    #
#                Big thanks to NoNonever for keeping updated                   #
#==============================================================================#
# To use, call pbSpeech(type, eventID, KeepAlive)
#
# Where type is either 1 or 2:
# 1 - Floating bubble
# 2 - Speech bubble with arrow
# 3 - Short arrow window
# 4 - Shocked window
#==============================================================================#
#Player Class Modifications
#==============================================================================#

class Game_Temp
  attr_accessor :speechbubble_bubble
  attr_accessor :speechbubble_vp
  attr_accessor :speechbubble_arrow
  attr_accessor :speechbubble_outofrange
  attr_accessor :speechbubble_talking
  attr_accessor :speechbubble_keepalive
  attr_accessor :speechbubble_direction
end

module MessageConfig
  BUBBLETEXTBASE  = Color.new(248,248,248)
  BUBBLETEXTSHADOW= Color.new(72,80,88)
end

#-------------------------------------------------------------------------------
# Function modifiers
#-------------------------------------------------------------------------------

class Window_AdvancedTextPokemon
  def text=(value)
    if value != nil && value != "" && $game_temp.speechbubble_bubble && $game_temp.speechbubble_bubble > 0
      if $game_temp.speechbubble_bubble == 4
        $game_temp.speechbubble_bubble = 0 if !$game_temp.speechbubble_keepalive
        resizeToFit2(value,130,64)
        @x = $game_map.events[$game_temp.speechbubble_talking].screen_x
        @y = $game_map.events[$game_temp.speechbubble_talking].screen_y - (32 + @height)
        if @y>(Graphics.height-@height-2)
          @y = (Graphics.height-@height)
        elsif @y<2
          @y=2
        end
        if @x>(Graphics.width-@width-2)
          @x = ($game_map.events[$game_temp.speechbubble_talking].screen_x-@width)
        elsif @x<2
          @x=2
        end        
      elsif $game_temp.speechbubble_bubble == 1
        $game_temp.speechbubble_bubble = 0 if !$game_temp.speechbubble_keepalive
        resizeToFit2(value,400,100)
        @x = $game_map.events[$game_temp.speechbubble_talking].screen_x
        @y = $game_map.events[$game_temp.speechbubble_talking].screen_y - (32 + @height)
            
        if @y>(Graphics.height-@height-2)
          @y = (Graphics.height-@height)
        elsif @y<2
          @y=2
        end
        if @x>(Graphics.width-@width-2)
          @x = ($game_map.events[$game_temp.speechbubble_talking].screen_x-@width)
        elsif @x<2
          @x=2
        end
      else
        $game_temp.speechbubble_bubble = 0 if !$game_temp.speechbubble_keepalive
      end
    end
    setText(value)
  end
end 

def pbRepositionMessageWindow(msgwindow, linecount=2)
  msgwindow.height=32*linecount+msgwindow.borderY
  msgwindow.y=(Graphics.height-msgwindow.height)
  if $game_temp && $game_temp.in_battle && !$scene.respond_to?("update_basic")
    msgwindow.y=0
  elsif $game_system && $game_system.respond_to?("message_position")
    case $game_system.message_position
    when 0  # up
      msgwindow.y=0
    when 1  # middle
      msgwindow.y=(Graphics.height/2)-(msgwindow.height/2)
    when 2
      if $game_temp.speechbubble_bubble==3 #Message over event
        $game_temp.speechbubble_direction="normal"
        msgwindow.setSkin("Graphics/windowskins/frlgtextskin")
        msgwindow.height = 100
        msgwindow.width = 400
        msgwindow.x = ($game_map.events[$game_temp.speechbubble_talking].screen_x)-(msgwindow.width/2)
        if msgwindow.x<0
          msgwindow.x=0
        end
        if msgwindow.x>(Graphics.width-msgwindow.width)
          msgwindow.x=Graphics.width-msgwindow.width
        end
        if $game_player.direction==2 #Facing down
          msgwindow.y = ($game_map.events[$game_temp.speechbubble_talking].screen_y)+14
          if msgwindow.y>(Graphics.height-msgwindow.height)
            msgwindow.y = ($game_map.events[$game_temp.speechbubble_talking].screen_y)-(msgwindow.height+60)
          end
        else
          msgwindow.y = ($game_map.events[$game_temp.speechbubble_talking].screen_y)-(msgwindow.height+60)
          if msgwindow.y<16
            msgwindow.y = ($game_map.events[$game_temp.speechbubble_talking].screen_y)+14
            $game_temp.speechbubble_direction="down"
          else
            $game_temp.speechbubble_direction="normal"
          end
        end
      elsif $game_temp.speechbubble_bubble==1
       msgwindow.setSkin("Graphics/windowskins/frlgtextskin")
       msgwindow.height = 100
       msgwindow.width = 400
      elsif $game_temp.speechbubble_bubble==4
       msgwindow.setSkin("Graphics/windowskins/shock")
       msgwindow.height = 100
       msgwindow.width = 400
      elsif $game_temp.speechbubble_bubble==2
       msgwindow.setSkin("Graphics/windowskins/frlgtextskin")
       msgwindow.height = 102
       msgwindow.width = Graphics.width
       if $game_player.direction==8
         $game_temp.speechbubble_vp = Viewport.new(0, 0, Graphics.width, 280)
         msgwindow.y = 6
       else
         $game_temp.speechbubble_vp = Viewport.new(0, 6 + msgwindow.height, Graphics.width, 280)
         msgwindow.y = (Graphics.height - msgwindow.height) - 6
         if $game_temp.speechbubble_outofrange==true
           msgwindow.y = 6
         end
       end
      else
        msgwindow.height = 102
        msgwindow.y = Graphics.height - msgwindow.height - 6
      end
    end
  end
  if $game_system && $game_system.respond_to?("message_frame")
    if $game_system.message_frame != 0
      msgwindow.opacity = 0
    end
  end
  if $game_message
    case $game_message.background
      when 1  # dim
        msgwindow.opacity=0
      when 2  # transparent
        msgwindow.opacity=0
    end
  end
end
 
def pbCreateMessageWindow(viewport = nil, skin = nil)
  arrow = nil
  if $game_temp.speechbubble_bubble==3 && $game_map.events[$game_temp.speechbubble_talking] != nil
    if $game_player.direction==2
      $game_temp.speechbubble_vp = Viewport.new(0, 0, Graphics.width, Graphics.height)
      $game_temp.speechbubble_vp.z = 999999
      arrow = Sprite.new($game_temp.speechbubble_vp)
      arrow.x = ($game_map.events[$game_temp.speechbubble_talking].screen_x)-17
      arrow.z = 999999
      if $game_map.events[$game_temp.speechbubble_talking].screen_y>240
        arrow.y = ($game_map.events[$game_temp.speechbubble_talking].screen_y)-60
        arrow.bitmap = RPG::Cache.load_bitmap("Graphics/Pictures/","DownArrow")
      else
        arrow.y = ($game_map.events[$game_temp.speechbubble_talking].screen_y)
        arrow.bitmap = RPG::Cache.load_bitmap("Graphics/Pictures/","UpArrow")
      end
    else
      $game_temp.speechbubble_vp = Viewport.new(0, 0, Graphics.width, Graphics.height)
      $game_temp.speechbubble_vp.z = 999999
      arrow = Sprite.new($game_temp.speechbubble_vp)
      arrow.x = ($game_map.events[$game_temp.speechbubble_talking].screen_x)-17
      arrow.z = 999999
      if $game_map.events[$game_temp.speechbubble_talking].screen_y>240
        arrow.y = ($game_map.events[$game_temp.speechbubble_talking].screen_y)-60
        arrow.bitmap = RPG::Cache.load_bitmap("Graphics/Pictures/","DownArrow")
      elsif $game_map.events[$game_temp.speechbubble_talking].screen_y<176
        arrow.y = ($game_map.events[$game_temp.speechbubble_talking].screen_y)
        arrow.bitmap = RPG::Cache.load_bitmap("Graphics/Pictures/","UpArrow")
      elsif $game_map.events[$game_temp.speechbubble_talking].screen_y>=176 && $game_map.events[$game_temp.speechbubble_talking].screen_y<=240
        arrow.y = ($game_map.events[$game_temp.speechbubble_talking].screen_y)-60
        arrow.bitmap = RPG::Cache.load_bitmap("Graphics/Pictures/","DownArrow")
      end
    end
  elsif $game_temp.speechbubble_bubble == 2 && ( $game_temp.speechbubble_talking == -1 || $game_map.events[$game_temp.speechbubble_talking] != nil) 
    # Determine speaker x and y (player or event)
    if $game_temp.speechbubble_talking == -1
      speaker_x = $game_player.screen_x
      speaker_y = $game_player.screen_y
    else
      speaker = $game_map.events[$game_temp.speechbubble_talking]
      speaker_x = speaker.screen_x
      speaker_y = speaker.screen_y
    end
    if $game_player.direction == 8
      $game_temp.speechbubble_vp = Viewport.new(0, 104, Graphics.width, 280)
      $game_temp.speechbubble_vp.z = 999999
      arrow = Sprite.new($game_temp.speechbubble_vp)
      arrow.x = speaker_x - Graphics.width
      arrow.y = (speaker_y - Graphics.height) - 136
      arrow.z = 999999
      arrow.bitmap = RPG::Cache.load_bitmap("Graphics/Pictures/","Arrow4")
      arrow.zoom_x = 2
      arrow.zoom_y = 2
      if arrow.x < -230
        arrow.x = speaker_x
        arrow.bitmap = RPG::Cache.load_bitmap("Graphics/Pictures/","Arrow3")
      end
    else
      $game_temp.speechbubble_vp = Viewport.new(0, 0, Graphics.width, 280)
      $game_temp.speechbubble_vp.z = 999999
      arrow = Sprite.new($game_temp.speechbubble_vp)
      arrow.x = speaker_x
      arrow.y = speaker_y
      arrow.z = 999999
      arrow.bitmap = RPG::Cache.load_bitmap("Graphics/Pictures/","Arrow1")
      if arrow.y >= Graphics.height-120
        $game_temp.speechbubble_outofrange = true
        $game_temp.speechbubble_vp.rect.y += 104
        arrow.x = speaker_x - Graphics.width
        arrow.bitmap = RPG::Cache.load_bitmap("Graphics/Pictures/","Arrow4")
        arrow.y = (speaker_y - Graphics.height) - 136
        if arrow.x < -250
          arrow.x = speaker_x
          arrow.bitmap = RPG::Cache.load_bitmap("Graphics/Pictures/","Arrow3")
        end
        if arrow.x >= 256
          arrow.x -= 15
          arrow.bitmap = RPG::Cache.load_bitmap("Graphics/Pictures/","Arrow3")
        end
      else
        $game_temp.speechbubble_outofrange = false
      end
      arrow.zoom_x = 2
      arrow.zoom_y = 2
    end
  end
  $game_temp.speechbubble_arrow = arrow
  msgwindow=Window_AdvancedTextPokemon.new("")
  if !viewport
    msgwindow.z=99999
  else
    msgwindow.viewport=viewport
  end
  msgwindow.visible=true
  msgwindow.letterbyletter=true
  msgwindow.back_opacity=MessageConfig::WINDOW_OPACITY
  pbBottomLeftLines(msgwindow,2)
  $game_temp.message_window_showing=true if $game_temp
  $game_message.visible=true if $game_message
  skin=MessageConfig.pbGetSpeechFrame() if !skin
  msgwindow.setSkin(skin)
  return msgwindow
end

def pbDisposeMessageWindow(msgwindow)
  $game_temp.message_window_showing=false if $game_temp
  $game_message.visible=false if $game_message
  msgwindow.dispose
  $game_temp.speechbubble_arrow.dispose if $game_temp.speechbubble_arrow
  $game_temp.speechbubble_vp.dispose if $game_temp.speechbubble_vp
end

def pbSpeech(status=0,value=0,keepalive=false)
  $game_temp.speechbubble_talking=get_character(value).id
  $game_temp.speechbubble_bubble=status
  $game_temp.speechbubble_keepalive=keepalive
end

def pbCallBub(status=0,value=0)
  $game_temp.speechbubble_talking=get_character(value).id
  $game_temp.speechbubble_bubble=status
end