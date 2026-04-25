#===============================================================================
# Edits to the Bag UI used while in Wonder Launcher battles.
#===============================================================================
class Window_PokemonBag < Window_DrawableCommand
  #-----------------------------------------------------------------------------
  # Aliased for displaying an item's Launcher Points.
  #-----------------------------------------------------------------------------
  alias launcher_drawItem drawItem
  def drawItem(index, _count, rect)
    launcher_drawItem(index, _count, rect)
    if $game_temp.wonder_launcher_mode && index != self.itemCount - 1
      rect = Rect.new(rect.x + 16, rect.y + 16, rect.width - 16, rect.height)
      thispocket = @bag.pockets[@pocket]
      item = (@filterlist) ? thispocket[@filterlist[@pocket][index]][0] : thispocket[index][0]
      item_data = GameData::Item.try_get(item)
      if item_data && item_data.is_launcher_item?
        pnttext = _ISPRINTF("{1: 3d} LP", item_data.launcher_points)
        xPnt    = rect.x + rect.width - self.contents.text_size(pnttext).width - 16
        textpos = [pnttext, xPnt, rect.y + 2, :left, baseColor, shadowColor]
        pbDrawTextPositions(self.contents, [textpos])
      end
    end
  end
end

class PokemonBag_Scene
  #-----------------------------------------------------------------------------
  # Aliased to display sprites and text related to Wonder Launcher mechanics.
  #-----------------------------------------------------------------------------
  alias launcher_pbRefresh pbRefresh
  def pbRefresh
    if $game_temp.wonder_launcher_mode && !PluginManager.installed?("Bag Screen w/int. Party")
      @sprites["leftarrow"].y = 226 if @sprites["leftarrow"]
      @sprites["rightarrow"].y = 226 if @sprites["rightarrow"]
      path = Settings::WONDER_LAUNCHER_PATH
      pocket = (@bag.last_viewed_pocket == 2) ? "medicine" : "battle"
      @sprites["background"].setBitmap(path + "bg_#{pocket}")
      @sprites["pocketicon"].bitmap.clear
      offset = (@sprites["itemlist"].pocket == 2) ? 0 : 1
      @sprites["pocketicon"].bitmap.blt(
        68 + (offset * 22), 2, @pocketbitmap.bitmap,
        Rect.new((@sprites["itemlist"].pocket - 1) * 28, 0, 28, 28)
      )
      @sprites["itemlist"].refresh
      pbRefreshIndexChanged
      overlay = @sprites["overlay"].bitmap
      points = $game_temp.player_launcher_points
      maxPoints = Settings::WONDER_LAUNCHER_MAX_POINTS
      item = GameData::Item.try_get(@sprites["itemlist"].item)
      x = ((186 - (10 * maxPoints + 2)) / 2).floor
      imagepos = [[path + "point_display", 2, 42]]
      maxPoints.times do |i|
        imagepos.push([path + "points", x + 10 * i, 86, 0, 0, 12, 14])
        if points >= i + 1
          tryPoints = (item) ? item.launcher_points : maxPoints + 1
          c = (points >= tryPoints && [points - tryPoints, 0].max < i + 1) ? 2 : 1
          imagepos.push([path + "points", x + 10 * i, 86, 12 * c, 0, 12, 14])
        end
      end
      pbDrawImagePositions(overlay, imagepos)
      pbDrawTextPositions(overlay, [
        [_INTL("Current LP"), 94, 56, :center, POCKETNAMEBASECOLOR, POCKETNAMESHADOWCOLOR],
        [sprintf("%d/%d", points, maxPoints), 94, 112, :center, ITEMTEXTBASECOLOR, ITEMTEXTSHADOWCOLOR]
      ]) 
    else
      launcher_pbRefresh
    end
  end
end

#===============================================================================
# Utility for finding the player's Key Items pocket.
#===============================================================================
class PokemonBag
  def get_key_items_pocket
    @pockets.each_with_index do |p, i|
      next if p.empty?
      next if !GameData::Item.get(p[0][0]).is_key_item?
      return i
    end
    return -1
  end
end