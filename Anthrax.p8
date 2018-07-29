pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
config = {
    menu = {bg = 2, tl = "menu"},
    play = {bg = 3, tl = "play"},
    pause = {bg = 0, tl = "pause"},
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
    elseif (state == "play") then
        update_play()
    elseif (state == "pause") then
        update_pause()
    end
end

function _draw()
    cls(config[state].bg)
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
    if (btnp(4)) then
        begin_play()
    end
end


--
-- play state handling
--

function begin_play()
    state = "pause"
    level = 1
    tm = 0
    sc = 0
    ball_list = {}
    shot_list = {}
    add_ball()
    add_ball()
    player = {
        x = 64,
        y = 128,
        sp = 1,
        lf = 6,
        invincible = 0,
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

    if player.lf <= 0 then
        state = "pause"
    end
end

--
-- pause state handling
--

function update_pause()
    config.pause.bg = config.play.bg

    if (btnp(4)) then
        if player.lf <= 0 then
            state = "menu"
        else
            state = "play"
        end
        sfx(0)
    end
end

--
-- player
--

function update_player()
    player.invincible -= 1/30
    if (btn(0)) and player.x > 8 then
        player.x -= 2
    elseif (btn(1)) and player.x < 121 then
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
            sfx(2)
        end
        -- collision with player
        if player.invincible <= 0 then
            local dx, dy = b.x - player.x, b.y - player.y + 12
            if abs(dx) < b.r + 4 and abs(dy) < b.r then
                player.lf -= 1
                player.invincible = 2
                sfx(7)
            end
        end
    end)
end


--
-- shots
--

function add_shot()
    add(shot_list, { 
        x=player.x,
        y=player.y - 25,
        vx=0,
        vy=-100
    })
    sfx(3)
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
            local dx, dy, dr = s.x - b.x, s.y - b.y, b.r + 2
            -- use /256 to avoid overflows
            if dx/256*dx + dy/256*dy < dr/256*dr then
                -- destroy ball or split ball
                if b.r < 5 then
                    del(ball_list, b)
                    sc += 20
                    sfx(5)
                else
                    b.r *= 5/8
                    b.vy = - abs(b.vy)
                    add(ball_list, { x=b.x, y=b.y, c=b.c, r=b.r, vx=-b.vx, vy=b.vy })
                    sc += 10
                    sfx(6)
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

function draw_play()
    foreach(ball_list, function(b)
        circfill(b.x, b.y, b.r, b.c)
        circ(b.x, b.y, b.r, 13)
        circfill(b.x - b.r * 0.3, b.y - b.r * 0.3, b.r * 0.35, 7)
    end)
    if player.invincible > 0 and rnd() > 0.5 then
        pal(14,7)
    end
    spr(player.sp, player.x - 8, player.y - 24, 2, 3)
    pal(14)
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
    print(sc, 3, 4, 0)
    for i = 1, player.lf do
        spr(32, 125 - 10*i, 3)
    end
end

config.menu.draw = function ()
    cprint("main menu", 40)
    cprint("press w", 50)
end

config.play.draw = function ()
    draw_play()
end

config.pause.draw = function ()
    draw_play()
    if player.lf <= 0 then
      cprint("game over", 40)
    else
      cprint("level "..tostr(level), 40)
    end
    cprint("press w", 50)
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
00110110eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01ee1881eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01e88881eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01e88881eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00188810eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00018100eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00001000eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
00020000330202a0402002016000110000d0000600001000011000100018700117000a70004700017000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300001c53020710257400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001e31031710193100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001d51023310275202c41031520000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000500002d640254302a6602243026650000000000000000000001940000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000243201e3301a3201533012320204002860000000000000360001600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001e75019750135500d75000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400001d0102301028020290201c02020030230302503017030190301b0501d05013050110500d0500b05009050080500405004050030500305003030020300103000020000100001000000000000000000000
