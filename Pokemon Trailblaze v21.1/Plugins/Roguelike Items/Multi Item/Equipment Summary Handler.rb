#===============================================================================
# Pokemon Summary handlers.
#===============================================================================
UIHandlers.add(:summary, :page_items, { 
  "name"      => "Items",
  "suffix"    => "items",
  "order"     => 11,
  "options"   => [:item, :nickname, :pokedex, :mark],
  "layout"    => proc { |pkmn, scene| scene.drawPageItems }
})