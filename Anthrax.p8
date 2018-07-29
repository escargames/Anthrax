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
      add(ball_list, { 
          x=crnd(10, 118), 
          y=crnd(10, 118), 
          r=crnd(5,10),
          vx=crnd(-20, 20),
          vy=crnd(-20, 20)
          })
      sfx(1)
    end

    foreach(ball_list, function(b)
      b.vy += 5
      b.x += b.vx / 30
      b.y += b.vy / 30
      if b.vx < 0 and (b.x - b.r) < 0 then
        b.vx = - b.vx
        sfx(2)
      end
       if b.vx > 0 and (b.x + b.r) > 128 then
        b.vx = - b.vx
        sfx(2)
      end
       if b.vy > 0 and (b.y + b.r) > 128 then
        b.vy = - b.vy
        b.y -= 2*(b.y + b.r - 128)
        sfx(2)
      end
    end)
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

function crnd(min, max)
  return min + rnd(max-min)
end

config.play.draw = function ()
  foreach(ball_list, function(b)
    circfill(b.x, b.y, b.r, 12)
    circ(b.x, b.y, b.r, 13)
    circfill(b.x - b.r * 0.3, b.y - b.r * 0.3, b.r * 0.35, 7)
  end)
end

__sfx__
00020000330202a0402002016000110000d0000600001000011000100018700117000a70004700017000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300001c53020710257400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001e35031750193500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
