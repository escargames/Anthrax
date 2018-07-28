pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
config = {
    menu = {bg = 2},
    play = {bg = 3}
}

function _init()
  state = "menu"
end

function _update()
  if (btn(0)) then
    state = "play"
  end
  --
  --
  if (state == "play") then
    --
    --
    if (btn(1)) then
      state = "menu"
    end
  end
end

function _draw()
  cls(config[state].bg)
  
end

__sfx__
00020000330202a0402002016000110000d0000600001000011000100018700117000a70004700017000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
