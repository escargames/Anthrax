pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
config = {
    menu = {bg = 2, tl = "menu", draw = function() end},
    play = {bg = 3, tl = "play", draw = 0}
}

function _init()
  state = "menu"
end

function _update()
  if (state == "menu") then
    if (btnp(0)) then
      state = "play"
      sfx(0)
    end
  end
  --
  --
  if (state == "play") then
    --
    --
    if (btnp(1)) then
      state = "menu"
      sfx(0)
    end
  end
end

function _draw()
  cls(config[state].bg)
  cprint(config[state].tl, 10)
  config[state].draw()
end

function cprint(text, y, color)
  local x = 64 - 2 * #text
  print(text, x, y+1, 7)
  print(text, x, y-1, 7)
  print(text, x-1, y, 7)
  print(text, x+1, y, 7)
  print(text, x, y, color)
end

config.play.draw = function ()
  cprint("coucou", 40, 14)
end

__sfx__
00020000330202a0402002016000110000d0000600001000011000100018700117000a70004700017000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
