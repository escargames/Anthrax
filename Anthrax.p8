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
      ball_list = {}
      sfx(0)
    end
  end
  --
  --
  if (state == "play") then
    if (btnp(2)) then
      add(ball_list, { x=10+rnd(118), y=10+rnd(118), r=5+rnd(5) })
      sfx(1)
    end
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
  foreach(ball_list, function(b)
    circfill(b.x, b.y, b.r, 12)
  end)
end

__sfx__
00020000330202a0402002016000110000d0000600001000011000100018700117000a70004700017000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300001c5301f210225400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
