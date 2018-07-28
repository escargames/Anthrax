pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
bg = {
    menu = 2,
    play = 3
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
  cls(bg[state])
end

__gfx__

__map__
