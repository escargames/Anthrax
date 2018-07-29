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
    cartdata("anthrax")
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
        new_game()
        begin_play()
    end
end


--
-- play state handling
--

function new_game()
    level = 1
    sc = 0
    lives = 3
end

function begin_play()
    state = "pause"
    tm = 0
    ball_list = {}
    shot_list = {}
    for i=1,level do
        add_ball()
    end
    player = {
        x = 64,
        y = 128,
        sp = 1,
        dir = false,
        walk = 0,
        bob = 0,
        invincible = 0,
    }
    sfx(0)
end

function update_play()
    tm += 1/30
    if (btnp(3)) then
        --add_ball()
    end

    update_balls()
    update_player()
    update_shots()

    if (btnp(2)) then
        add_shot()
    end

    if #ball_list == 0 then
        shot_list = {}
        level += 1
        state = "pause"
    end

    if lives <= 0 then
        shot_list = {}
        state = "pause"
        for i = 2,4 do
            if dget(i) < sc then
                dset(i-1,dget(i))
                dset(i, sc)
            end
        end    
    end      
end

--
-- pause state handling
--

function update_pause()
    config.pause.bg = config.play.bg

    if (btnp(4)) then
        if lives <= 0 then
            state = "menu"
        elseif #ball_list == 0 then
            begin_play()
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
    player.bob += 1/30
    player.invincible -= 1/30
    if (btn(0)) and player.x > 8 then
        player.dir = true
        player.walk += 1/30
        player.x -= 2
    elseif (btn(1)) and player.x < 121 then
        player.dir = false
        player.walk += 1/30
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
                lives -= 1
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
        y=player.y - 28,
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
    cls(12)
    local p={0xffff,0xafaf,0xa5a5,0x0505,0x0}
    for n=1,#p do
        fillp(p[n]+0x.8)
        circfill(64-n*6,64+n*6,80-(n-1)*15,6)
    end
    fillp()
    circfill(100,500,400,3)
    for n=1,#p do
        fillp(p[n]+0x.8)
        circfill(100,500,400-(n-1)*6,11)
    end
    fillp()

    foreach(ball_list, function(b)
        fillp(0xa5a5.8)
        circfill(b.x, b.y, b.r, b.c)
        fillp()
        circ(b.x, b.y, b.r, 0)
        circfill(b.x - b.r * 0.3, b.y - b.r * 0.3, b.r * 0.35, 7)
    end)

    if player.invincible > 0 and sin(4*player.invincible) > 0 then
        for i=1,16 do pal(i,7) end
    end
    spr(33, player.x - 4, player.y - 25 + sin(2*player.walk), 1, 1, player.dir)
    spr(player.sp, player.x - 8, player.y - 18, 2, 3, player.dir)
    spr(player.sp+4+2*flr(player.walk*4%2), player.x - 8, player.y - 16, 2, 2, player.dir)
    spr(player.sp+2, player.x - 8, player.y - 24 + sin(player.bob), 2, 2, player.dir)
    pal()
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
    for i = 1, lives do
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
    if lives <= 0 then
        cprint("game over", 30)
        cprint("score: "..tostr(sc), 40)
        cprint("highscores: 1."..tostr(dget(4)), 80)
        cprint("2."..tostr(dget(3)), 90)
        cprint("3."..tostr(dget(2)), 100)
    elseif #ball_list == 0  and level > 1 then
        cprint("congrats! score: "..tostr(sc), 40)
    else
        cprint("level "..tostr(level), 40)
    end
    cprint("press w", 50)
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000002222240000000009999940000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0007700000022244449400000009aaaaa42400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0007700000024999997940000099aa77794290000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700002499949999400002299999944290000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000002299949999400002944999424290000000442222240000000002444224000000000000000000000000000000000000000000000000000000000000
0000000000249a9999924000092aaa977929900000009949aa990000000029949a99000000000000000000000000000000000000000000000000000000000000
0022200000499a999994400009922999449a900000009a499aa9900000004a949aa9900000000000000000000000000000000000000000000000000000000000
027aa200004999a499424000029944444aa9200000099a9499aa90000000499499a9900000000000000000000000000000000000000000000000000000000000
27a777200044999949942000029aaa99a992000000049aa9442ef60000004ea9499ff60000000000000000000000000000000000000000000000000000000000
27777a200000999999920000002299999220000000002222000ff6000000fff2449ff60000000000000000000000000000000000000000000000000000000000
027772000000000000000000000022222000000000006ff0006ff600000006f10011f00000000000000000000000000000000000000000000000000000000000
01c7a100000000000000000000000000000000000006fff00111c000000006111011c00000000000000000000000000000000000000000000000000000000000
0027200000000000000000000000000000000000000c11100111ccc00000c11100111cc000000000000000000000000000000000000000000000000000000000
001c10000000000000000000000000000000000000c1111000111110000011100001111000000000000000000000000000000000000000000000000000000000
00000000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00110110006700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01ee1881006700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01e88881006700000000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01e88881006500000000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00188810006500000000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00018100006500000000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00001000006500000000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
00020000330202a0402002016000110000d0000600001000011000100018700117000a70004700017000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300001c53020710257400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001e31031710193100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001d51023310275202c41031520000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000500002d640254302a6602243026650000000000000000000001940000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000243201e3301a3201533012320204002860000000000000360001600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001e75019750135500d75000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400001d0102301028020290201c02020030230302503017030190301b0501d05013050110500d0500b05009050080500405004050030500305003030020300103000020000100001000000000000000000000
