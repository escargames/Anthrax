pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
config = {
    menu = {bg = 2, tl = "menu", draw = function() end},
    play = {bg = 3, tl = "play", draw = 0}
}


--
-- standard pico-8 workflow
--

function _init()
    state = "menu"
end

function _update()
    if (state == "menu") then
        update_menu()
    end
  
    if (state == "play") then
        update_play()
    end
end

function _draw()
    cls(config[state].bg)
    cprint(config[state].tl, 10)
    config[state].draw()
end


--
-- cool functions
--

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


--
-- menu state handling
--

function update_menu()
    if (btnp(2)) then
        begin_play()
    end
end


--
-- play state handling
--

function begin_play()
    state = "play"
    tm = 0
    ball_list = {}
    shot_list = {}
    add_ball()
    player = {
        x = 56,
        y = 104,
        sp = 1,
    }
    sfx(0)
end

function update_play()
    tm += 1/30
    if (btnp(3)) then
        --add_ball()
    end

    if tm > 2 then
        update_balls()
    end

    update_player()
    update_shots()

    if (btnp(2)) then
        add_shot()
    end

    if (btnp(3)) then
        state = "menu"
        sfx(0)
    end
end


--
-- player
--

function update_player()
    if (btn(0)) and player.x > 0 then
        player.x -= 2
    elseif (btn(1)) and player.x < 113 then
        player.x += 2
    end
end


--
-- balls
--

function add_ball()
    add(ball_list, { 
        x=crnd(10, 118),
        y=crnd(16, 48),
        c=crnd(9,13),
        r=10,
        vx=20,
        vy=crnd(-20, 20)
    })
    sfx(1)
end

function update_balls()
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
        end
    end)
end


--
-- shots
--

function add_shot()
    add(shot_list, { 
        x=player.x + 8,
        y=player.y - 1,
        vx=0,
        vy=-100
    })
    sfx(1)
end

function update_shots()
    foreach(shot_list, function(s)
        s.x += s.vx / 30
        s.y += s.vy / 30
        if s.y < -50 then
            del(shot_list, s)
            return
        end
        for i = 1,#ball_list do
            local b=ball_list[i]
            local dx, dy = s.x - b.x, s.y - b.y
            if dx*dx + dy*dy < b.r*b.r + 2*2 then
                -- destroy ball or split ball
                if b.r < 5 then
                    del(ball_list, b)
                else
                    b.r *= 5/8
                    b.vy = - abs(b.vy)
                    add(ball_list, { x=b.x, y=b.y, c=b.c, r=b.r, vx=-b.vx, vy=b.vy })
                end
                -- destroy shot
                del(shot_list, s)
                break
            end
        end
    end)
end


--
-- drawing
--

config.play.draw = function ()
    foreach(ball_list, function(b)
        circfill(b.x, b.y, b.r, b.c)
        circ(b.x, b.y, b.r, 13)
        circfill(b.x - b.r * 0.3, b.y - b.r * 0.3, b.r * 0.35, 7)
    end)
    spr(player.sp, player.x, player.y, 2, 3)
    foreach(shot_list, function(b)
        spr(16, b.x-4, b.y-4)
        pset(b.x+crnd(-2,1), b.y+rnd(8), 7)
        pset(b.x+crnd(-2,1), b.y+rnd(8), 7)
        pset(b.x+crnd(-2,1), b.y+rnd(8), 7)
        pset(b.x+crnd(-2,1), b.y+rnd(8), 7)
        --circfill(b.x, b.y, 2, 1)
        --circ(b.x, b.y, b.r, 13)
        --circfill(b.x - b.r * 0.3, b.y - b.r * 0.3, b.r * 0.35, 7)
    end)
end

__gfx__
00000000eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007aa000eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07a77700eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777a00eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777000eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00c7a000eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00070000eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000c0000eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
00020000330202a0402002016000110000d0000600001000011000100018700117000a70004700017000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300001c53020710257400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001e31031710193100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
