pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
config = {
    menu = {bg = 2, tl = "menu"},
    play = {bg = 3, tl = "play"}
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
  print(config[state].tl, 60, 10)
end

__sfx__
00020000330202a0402002016000110000d0000600001000011000100018700117000a70004700017000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
