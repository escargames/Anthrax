pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
--anthrax
--by niarkou & sam
config = {
    menu = {tl = "menu"},
    play = {tl = "play"},
    pause = {tl = "pause"},
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
    config[state].draw()
end

--
-- cool functions
--
function coprint(text, x, y, color)
    print(text, x, y+1, 1)
    print(text, x, y-1, 1)
    print(text, x-1, y-1, 1)
    print(text, x+1, y+1, 1)
    print(text, x-1, y, 1)
    print(text, x+1, y, 1)

    print(text, x, y, color or 7)
end

function cprint(text, y, color)
    local x = 64 - 2 * #text
    coprint(text, x, y, color or 7)
end

function crnd(min, max)
    return min + rnd(max-min)
end

function ccrnd(tab)  -- takes a tab and choose randomly between the elements of the table
  n = flr(crnd(1,#tab+1))
  return tab[n]
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

function cosprint(text, x, y, height, color)
    -- save first line of image
    local save={}
    for i=1,96 do save[i]=peek4(0x6000+(i-1)*4) end
    memset(0x6000,0,384)
    print(text, 0, 0, 7)
    -- restore image and save first line of sprites
    for i=1,96 do local p=save[i] save[i]=peek4((i-1)*4) poke4((i-1)*4,peek4(0x6000+(i-1)*4)) poke4(0x6000+(i-1)*4, p) end
    -- cool blit
    pal() pal(7,0)
    for i=-1,1 do for j=-1,1 do sspr(0, 0, 128, 6, x+i, y+j, 128 * height / 6, height) end end
    pal(7,color)
    sspr(0, 0, 128, 6, x, y, 128 * height / 6, height)
    -- restore first line of sprites
    for i=1,96 do poke4(0x0000+(i-1)*4, save[i]) end
    pal()
end

function csprint(text, y, height, color)
    local x = 64 - (2 * #text - 0.5) * height / 6
    cosprint(text, x, y, height, color)
end

--
-- play state handling
--

function new_game()
    level = 1
    sc = 0
    lives = 3
    bonus = {}
end

function begin_play()
    state = "pause"
    hourglass = false
    forcefield = 0
    tm = 0
    ball_list = {}
    shot_list = {}
    for i=1,level do
        add_ball()
    end
    player = {
        x = 64,
        y = 126,
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

    if not hourglass then
        move_balls()
    elseif hourglass > 0 then
        hourglass -= 1
    else hourglass = false
    end

    if forcefield > 0 then
        forcefield -= 0.5
    else forcefield = 0
    end

    update_balls()
    update_player()
    update_shots()
    update_bonus()
    activate_bonus()

    if (btnp(5)) then
        add_shot()
    end

    if #ball_list == 0 then
        shot_list = {}
        level += 1
        lives += 1
        state = "pause"
    end

    if lives <= 0 then
        shot_list = {}
        state = "pause"
        for i = 3,1,-1 do
            if dget(i) < sc then
                dset(i+1,dget(i))
                dset(i, sc)
            end
        end    
    end      
end

--
-- pause state handling
--

function update_pause()
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
        vx=ccrnd({-20, 20}),
        vy=crnd(-20, 20),
        bounced = 0
    })
end

function move_balls()
    foreach(ball_list, function(b)
        if not b.dead then
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
        end
    end)
end

function update_balls()
    foreach(ball_list, function(b)
        
        if b.bounced > 0 then
            b.bounced -= 1
        else b.bounced = 0
        end

        if b.dead and b.dead > 1 then
            b.dead -= 1
        elseif b.dead then
            b.dead = 1
        end

        -- destroy ball
        if b.dead == 1 then
            del(ball_list, b)
        end

        -- collision with player
        local dx, dy = b.x - player.x, b.y - player.y + 12
        if abs(dx) < b.r + 4 and abs(dy) < b.r + 10 then
            if forcefield > 0 then
                if b.bounced < 1 then
                    b.bounced = 30
                    if dx < 4 then
                        b.vx = - b.vx
                        sfx(2)
                    end
                    if dy < 4 then
                        b.vy = - b.vy
                        sfx(2)
                    end
                end
            elseif player.invincible <= 0 then
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
                -- sometimes bonus
                    if rnd() < 0.1 then
                        add(bonus, { type = ccrnd({0, 1, 2}), x = b.x, y = b.y, vx=ccrnd({-b.vx, b.vx}), vy=b.vy})
                    end
                -- destroy ball or split ball
                if b.r < 5 then
                    b.dead = 31
                    sc += 20
                    sfx(5)
                else
                    b.r *= 5/8
                    b.dead = 31
                    b.vy = - abs(b.vy)
                    add(ball_list, { x=b.x, y=b.y, c=b.c, r=b.r, vx=-b.vx, vy=b.vy, bounced = 0 })
                    add(ball_list, { x=b.x, y=b.y, c=b.c, r=b.r, vx=b.vx, vy=b.vy, bounced = 0 })
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
-- bonus
--

function update_bonus()
    if not hourglass then
        foreach(bonus, function(b)
            if b.vy > 0 and (b.y + 15) > 128 then
                b.vy = 0
                b.vx = 0
                b.y = 117
            else
                b.vy += 5
                b.x += b.vx / 30
                b.y += b.vy / 30
            end
            if b.vx < 0 and b.x < 2 then
                b.vx = - b.vx
                sfx(2)
            end
            if b.vx > 0 and (b.x + 7) > 128 then
                b.vx = - b.vx
                sfx(2)
            end
        end)
    end
end

function activate_bonus()
    foreach(bonus, function(b)
        local dx, dy = b.x - player.x, b.y - player.y + 12
        if abs(dx) < 7 and abs(dy) < 8 then
            if b.type == 0 then -- bonus is an hourglass
                hourglass = 60
            elseif b.type == 1 then -- bonus is a bomb
                foreach(ball_list, function(ball)
                    if ball.r < 5 then
                        ball.dead = 31
                    end
                end)
            elseif b.type == 2 then -- bonus is a force field
                forcefield = 60
            end
            del(bonus, b)
        end
    end)
end

--
-- drawing
--

function draw_world()
    cls(12)
    local p={0xffff,0xfafa,0x5a5a,0x5050,0x0}
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
end

function draw_play()
    draw_world()

    foreach(ball_list, function(b)
        if not b.dead or b.dead == 1 then
            fillp(0xa5a5.8)
            circfill(b.x, b.y, b.r, b.c)
            fillp()
            circ(b.x, b.y, b.r, 1)
            circfill(b.x - b.r * 0.3, b.y - b.r * 0.3, b.r * 0.35, 7)
        end
        
        if b.dead and b.dead > 1 then
            local deadbubbles = 5
            for i = 1, deadbubbles do
                fillp(0xa5a5.8)
                circfill(b.x + crnd(-(b.r - 1), b.r - 1), b.y + crnd(-(b.r - 1), b.r - 1), crnd(1, b.r - 1), b.c)
                fillp()
            end
        end
    end)

    foreach(bonus, function(b)
        palt(0, false)
        palt(14, true)
        if b.type == 0 then
            spr(9, b.x, b.y, 2, 2)
        elseif b.type == 1 then
            spr(37, b.x, b.y, 2, 2)
        elseif b.type == 2 then
            spr(39, b.x, b.y, 2, 2)
        end
        palt()
    end)

    if forcefield > 0 then
        fillp(0x5a5a + 0x.8)
        circfill(player.x - 1, player.y - 15, 11, 7)
        circfill(player.x - 1, player.y - 8, 11, 7)
        fillp()
    end

    if player.invincible > 0 and sin(4*player.invincible) > 0 then
        for i=1,16 do pal(i,7) end
    end
    spr(33, player.x - 4, player.y - 25 + sin(2*player.walk), 1, 1, player.dir)
    spr(player.sp, player.x - 8, player.y - 18, 2, 2, player.dir)
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

    coprint("score: "..tostr(sc), 3, 4, 7)
    if lives < 7 then
        for i = 1, lives do
        	spr(32, 125 - 10*i, 3)
        end
	else
		    spr(32, 115, 3)
		    coprint(lives, 110, 5)
    end
end

function draw_highscores()
    cprint("highscores:", 80)
    cprint("1..."..tostr(dget(1)), 90)
    cprint("2..."..tostr(dget(2)), 100)
    cprint("3..."..tostr(dget(3)), 110)
end

function draw_debug()
    print ("bonus  "..#bonus, 80, 120)
end

config.menu.draw = function ()
    draw_world()
    csprint("anthrax", 20, 12, 14)
    cprint("a game about bubbles", 40)
    cprint("press 🅾️ to play", 60, 9)
    draw_highscores()
end

config.play.draw = function ()
    draw_play()
    --draw_debug()
end

config.pause.draw = function ()
    draw_play()
    if lives <= 0 then
        cprint("game over", 40, 8)
        cprint("score: "..tostr(sc), 50)
        draw_highscores()
    elseif #ball_list == 0  and level > 1 then
        cprint("congrats! score: "..tostr(sc), 40)
    else
        cprint("level "..tostr(level), 40)
    end
    cprint("press 🅾️ to continue", 60, 9)
end

__gfx__
000000000000000000000000000000000000000000000000000000000000000000000000eeeeeeeeeeeeeeee0000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000eeeeeee0000000000000000000000000000000000000000
007007000000022222400000000099999400000000000000000000000000000000000000566666665eeeeeee0000000000000000000000000000000000000000
0007700000022244449400000009aaaaa424000000000000000000000000000000000000e0fffaf0eeeeeeee0000000000000000000000000000000000000000
0007700000024999997940000099aa777942900000000000000000000000000000000000ee5aff5eeeeeeeee0000000000000000000000000000000000000000
007007000024999499994000022999999442900000000000000000000000000000000000eee5f0eeeeeeeeee0000000000000000000000000000000000000000
000000000022999499994000029449994242900000004422222400000000024442240000eee065eeeeeeeeee0000000000000000000000000000000000000000
0000000000249a9999924000092aaa977929900000009949aa990000000029949a990000ee06665eeeeeeeee0000000000000000000000000000000000000000
0022200000499a999994400009922999449a900000009a499aa9900000004a949aa99000e5fffaf0eeeeeeee0000000000000000000000000000000000000000
027aa200004999a499424000029944444aa9200000099a9499aa90000000499499a990005fafffff5eeeeeee0000000000000000000000000000000000000000
27a777200044999949942000029aaa99a992000000049aa9442ef60000004ea9499ff600000000000eeeeeee0000000000000000000000000000000000000000
27777a200000999999920000002299999220000000002222000ff6000000fff2449ff600eeeeeeeeeeeeeeee0000000000000000000000000000000000000000
027772000000000000000000000022222000000000006ff0006ff600000006f10011f000eeeeeeeeeeeeeeee0000000000000000000000000000000000000000
01c7a100000000000000000000000000000000000006fff00111c000000006111011c000eeeeeeeeeeeeeeee0000000000000000000000000000000000000000
0027200000000000000000000000000000000000000c11100111ccc00000c11100111cc0eeeeeeeeeeeeeeee0000000000000000000000000000000000000000
001c10000000000000000000000000000000000000c11110001111100000111000011110eeeeeeeeeeeeeeee0000000000000000000000000000000000000000
0000000000600000000000000000000000000000eeeeee9eeeeeeeeee00000000eeeeeee00000000000000000000000000000000000000000000000000000000
0011011000670000000000000000000000000000eeee55eeeeeeeeeeea666666d0eeeeee00000000000000000000000000000000000000000000000000000000
01ee188100670000000000000000000000000000eee5eeeeeeeeeeee07666666d0eeeeee00000000000000000000000000000000000000000000000000000000
01e8888100670000000000007000000000000000eeee5eeeeeeeeeee07666666d0eeeeee00000000000000000000000000000000000000000000000000000000
01e8882100650000000000007000000000000000ee00000eeeeeeeee07666666d0eeeeee00000000000000000000000000000000000000000000000000000000
0018821000650000000000007000000000000000e0700000eeeeeeee57666666d0eeeeee00000000000000000000000000000000000000000000000000000000
0001210000650000000000007000000000000000070000000eeeeeee0a666666d0eeeeee00000000000000000000000000000000000000000000000000000000
0000100000650000000000007000000000000000000000000eeeeeeee07666660eeeeeee00000000000000000000000000000000000000000000000000000000
0000000000000000000000007000000000000000000000000eeeeeeeee576660eeeeeeee00000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000e0000000eeeeeeeeeee07a0eeeeeeeee00000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000ee00000eeeeeeeeeeeee00eeeeeeeeee00000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee00000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee00000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee00000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee00000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee00000000000000000000000000000000000000000000000000000000
__label__
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccc111c111c11111111111cccccccc1111111c1111cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cc11771177117717771777111ccccc1777177117771cccccccccccccccccccccccccccccccccccccccccccccccccccccc11c11ccccc11c11ccccc11c11cccccc
cc171117111717171717111171cccc1717117117171ccccccccccccccccccccccccccccccccccccccccccccccccccccc1ee1881ccc1ee1881ccc1ee1881ccccc
cc1777171c171717711771c111cccc1777117117171ccccccccccccccccccccccccccccccccccccccccccccccccccccc1e88881ccc1e88881ccc1e88881ccccc
cc11171711171717171711c171ccccc117117117171ccccccccccccccccccccccccccccccccccccccccccccccccccccc1e88881ccc1e88881ccc1e88881ccccc
cc177111771771171717771c11cccccc17177717771cccccccccccccccccccccccccccccccccccccccccccccccccccccc18881ccccc18881ccccc18881cccccc
ccc111cc111111c11111111cccccccccc1111111111ccccccccccccccccccccccccccccccccccccccccccccccccccccccc181ccccccc181ccccccc181ccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc1ccccccccc1ccccccccc1cccccccc
ccccccccccccccccccccccccccccccccccccccccccccc6c6c6c6c6c6c6c6cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccc6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6cccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccc6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6cccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccc6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6cccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccc6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6cccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccc6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6cccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccc6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6cccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccc6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6cccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccc6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c611111116c6c6cccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc11cacacac11ccccccccccccccccccccccccccccccccccc
ccccccc6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c1a6a6a6a6a6a1c6c6cccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc1acacacacacaca1ccccccccccccccccccccccccccccccccc
ccccc6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c1a6a777a6a6a6a6a1c6c6cccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccc6c6c6c6c6c6c6ccccccccccccccccccccccccc1aca77777acacacaca1ccccccccccccccccccccccccccccccc
ccc6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c616a7777777a6a6a6a616c6c6cccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccc6c6c6c6c6c6c6c6c6c6c6c6c6c6c6cccccccccccccccc1cac7777777cacacacac1cccccccccccccccccccccccccccccc
ccc6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c1a6a7777777a6a6a6a6a1c6c6cccccccccccccccccccccccccc
cccccccccccccccccccccccccc6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6cccccccccc1caca77777acacacacac1cccccccccccccccccccccccccccccc
c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c1a6a6a777a6a6a6a6a6a1c6c6c6cccccccccccccccccccccccc
cccccccccccccccccccccc6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6cccccc1cacacacacacacacacac1cccccccccccccccccccccccccccccc
c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c1a6a6a6a6a6a6a6a6a6a1c6c6c6c6cccccccccccccccccccccc
cccccccccccccccccccc6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6cccc1cacacacacacacacacac1cccccccccccccccccccccccccccccc
c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c616a6a6a6a6a6a6a6a616c6c6c6c6c6cccccccccccccccccccc
cccccccccccccccc6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c1acacacacacacacaca1ccccccccccccccccccccccccccccccc
c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c1a6a6a6a6a6a6a6a1c6c6c6c6c6c6cccccccccccccccccccc
cccccccccccccc6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c1acacacacacaca1ccccccccccccccccccccccccccccccccc
c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c1a6a6a6a6a6a1c6c6c6c6c6c6c6c6cccccccccccccccccc
cccccccccccc6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c11cacacac11ccccccccccccccccccccccccccccccccccc
c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c67116c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c62226c6c611111116c6c6c611111116c6c711cccccccccccccccc
cccccccccc6c6c6c6c6c6c6c6c6c6c6777616c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c627aa26c6ccccccccccccc11cbcbcbc11c77791ccccccccccccccc
c6c6c6c6c6c6c6c6c6c6c6c6c6c6c616769616c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c627a77726c6c6c6c6c6c6c1b6b6b6b6b6b1979691cccccccccccccc
cccccccc6c6c6c6c6c6c6c6c6c6c6c1969691c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c27777a2c6c6ccccccccc1bcbcbcbcbcbcb19c9c1cccccccccccccc
c6c6c6c6c6c6c6c6c6c6c6c6c6c6c616969616c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c27772c6c6c6c6c6c6c1b6b777b6b6b6b1b19691cccccccccccccc
cccccc6c6c6c6c6c6c6c6c6c6c6c6c6169616c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c61c7a16c6c6c6ccccc1bcb77777bcbcbcb1b191ccccccccccccccc
c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c611166666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c6c62776c6c6c6c6c6c616b7777777b6b6b6b111c6cccccccccccccc
cccccc6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c171c6c6c6c6cccc1cbc7777777cbcbcbcbc1cccccccccccccccc
c6c6c6c6c6c6c6c6c6c6c6c6c6c666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c1b6b7777777b6b6b6b6b1c6cccccccccccccc
cccc6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6cc1cbcb77777bcbcbcbcbc1cccccccccccccccc
c6c6c6c6c6c6c6c6c6c6c6c66666666666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c1b6b6b777b6b6b6b6b6b1c6cccccccccccccc
cc6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c61cbcbcbcbcbcbcbcbcbc1cccccccccccccccc
c6c6c6c6c6c6c6c6c6c6666666666666666666666666666666666666666666c6c6c6c6c6c6c6c7c6c6c6c6c6c6c1b6b6b6b6b6b6b6b6b6b1c6c6cccccccccccc
cc6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c61cbcbcbcbcbcbcbcbcbc1cccccccccccccccc
c6c6c6c6c6c6c6c6c66666666666666666666666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c616b6b6b6b6b6b6b6b616c6c6cccccccccccc
6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c1bcbcbcbcbcbcbcbcb1ccccccccccccccccc
c6c6c6c6c6c6c6c666666666666666666666666666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c1b6b6b6b6b6b6b6b1c6c6c6cccccccccccc
6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c1bcbcbcbcbcbcb1ccccccccccccccccccc
c6c6c6c6c6c6c6666666666666666666666666666666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c1b6b6b6b6b6b1c6c6c6c6cccccccccccc
6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6ccc11cbcbcbc11ccccccccccccccccccccc
c6c6c6c6c6c66666666666666666666666666666666666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c611111116c6c6c6c6c6cccccccccccc
6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6ccccccccccccccccccccccccccccccccc
c6c6c6c6c6c66666666666666666666666666666666666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6cccccccccc
6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6ccccccccccccccccccccccccccccccccc
c6c6c6c6c666666666666666666666666666666666666666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6cccccccccc
6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6ccccccccccccccccccccccccccccccccc
c6c6c6c6666666666666666666666666666666666666666666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6cccccccccc
6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6ccccccccccccccccccccccccccccccccc
c6c6c6c6666666666666666666666666666666666666666666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6cccccccccc
6c6c6c6c6c6c6c6c6c6c6c6c666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6ccccccccccccccccccccccccccccccc
c6c6c6c6666666666666666666666666666666666666666666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6cccccccccc
6c6c6c6c6c6c6c6c6c6c6c6666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6ccccccccccccccccccccccccccccccc
c6c6c66666666666666666666666666666666666666666666666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6cccccccccc
6c6c6c6c6c6c6c6c6c6c66666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6ccccccccccccccccccccccccccccccc
c6c6c66666666666666666666666666666666666666666666666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6cccccccccc
6c6c6c6c6c6c6c6c6c666666666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6ccccccccccccccccccccccccccccccc
c6c6c66666666666666666666666666666666666666666666666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6cccccccccc
6c6c6c6c6c6c6c6c6666666666666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6ccccccccccccccccccccccccccccccc
c6c6c66666666666666666666666666666666666666666666666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6cccccccccccc
6c6c6c6c6c6c6c6c6611111666666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6ccccccccc11111ccccccccccccccccc
c6c6c6666666666661b6b6b16666666666666666666666666666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c6c1b6b6b1c6c6cccccccccccc
6c6c6c6c6c6c6c6617776b6b1666666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6ccccccc1777cbcb1ccccccccccccccc
c6c6c66666666661777776b6b166666666666666666666666666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c1777776b6b1c6cccccccccccc
6c6c6c6c6c6c6c1b77777b6b6b16666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6ccccccc1b77777bcbcb1ccccccccccccc
c6c6c66666666616777776b6b616666666666666666666666666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c616777776b6b616cccccccccccc
6c6c6c6c6c6c6c1b67776b6b6b16666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6ccccccc1bc777cbcbcb1ccccccccccccc
c6c6c66666666616b6b6b6b6b616666666666666666666666666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c616b6b6b6b6b616cccccccccccc
6c6c6c6c6c6c6c1b6b6b6b6b6b16666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6ccccccc1bcbcbcbcbcb1ccccccccccccc
c6c6c66666666661b6b6b6b6b166666666666666666666666666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c1b6b6b6b6b1cccccccccccccc
6c6c6c6c6c6c6c661b6b6b6b1666666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6ccccccccc1bcbcbcb1ccccccccccccccc
c6c6c6666666666661b6b6b16666666666666666666666666666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c6c1b6b6b1c6cccccccccccccc
6c6c6c6c6c6c6c66661111166666666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6ccccccccccccc11111ccccccccccccccccc
c6c6c6c6666666666666666666666666666666666666666666666666666666666666666666c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6cccccccccccccc
6c6c6c6c6c6c6c66666666666666666666666666666666666666666c6c666c6c6c6c6c6c6c6c6c6c6333333333333333333333333333333333333333cccccccc
c6c6c6c6666666666666666666666666666666666666666666666666667666666633333333333333333333333333333333333333333333333333333333333333
6c6c6c6c6111116c6666666666666666666666666666666666666c6c337633333333333333333333331111133333333333333333333333333333333333333333
c6c6c6c616c6c616666666666666666666666666666666663333333349999933333333333333333331c3c3c13333333333333333333333333333333333333333
cc6c6c616c6c6c6166666666666666666666666663333333333333424aaaaa9333333333333333331c3c3c3c1333333333333333333333333333333333333333
c6c6c6167776c6c611116666666666666633333333333333333339249777aa993333333333333331c777c3c3c133333333333333333333333111333333333333
cc6c616777776c6c116916666666633333333333333333333333392449999992233333333333331c77777c3c3c13333333333333333333331739133333333333
c6c6c1c77777c6c1c17691633333333333333333333333333333392424999449233b3b3b3b3b3b1b77777bcbcb1b3b3b3b3b3b3b3b3b3b31777b913b3b3b3b3b
cccc616777776c6c61393133333333333333333333333333333339929779aaa2933333333333331c77777c3c3c13333333333333333333313739313333333333
c6c6c1c67776c6c1c19391333333333333333333333333333b3b39a9449992299b3b3b3b3b3b3b1bc777cbcbcb1b3b3b3b3b3b3b3b3b3b319b9b913b3b3b3b3b
ccccc16c6c3c3c3c113913333333333333333333333333333333329aa4444499233333333333331c3c3c3c3c3c13333333333333333333331939133333333333
c6c6c313c3c3c3c31111333333333333333b3b3b3b3b3b3b3b3b3b299a99aaa92b3b3b3b3b3b3b31cbcbcbcbc13b3b3b3b3b3b3b3b3b3b3b31113b3b3b3b3b3b
c33333313c3c3c3133333333333333333333333333333333333334922999992233333333333333331cbcbcbc13b3b3b3b3b3b3b3b3b3b3b3b3b3b3b333333333
3333333313c3c313333333333b3b3b3b3b3b3b3b3b3b3b3b3b3b3499922222423b3b3b3b3b3b3b3b31cbcbc13b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b
3333333331111133333333333333333333333333333333333333349999499922b3b3b3b3b3b3b3b3b3111113b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3
333333333333333b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b34299999a9423b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b
333333333333333333333333333333333333333333b3b3b3b3b3b44222224494b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3
3333333b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3499aa9499943b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b
333333333333333333333333333333b3b3b3b3b3b3b3b3b3b3b3b99aa994a944b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3
3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b39aa9949a99b3b3bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
33333333333333333333b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b36fe2449aa943b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3
3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3bbb6ffbbb2222bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
333333333333b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b36ff6b3bff6b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3
3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3bbbbbbbbbbbbbbbbbbc111bbfff6bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
3333b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3bccc1113b111c3b3b3b3b3b3b3b3b3bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb3b3b3b3
3b3b3b3b3b3b3b3b3b3b3b3b3bbbbbbbbbbbbbbbbbbbbbbbbbb11111bbb1111cbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
3b3b3b3b3b3b3b3bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb

__sfx__
00020000330202a0402002016000110000d0000600001000011000100018700117000a70004700017000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300001c53020710257400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001e31031710193100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001d51023310275202c41031520000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000500002d640254302a6602243026650000000000000000000001940000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000243201e3301a3201533012320204002860000000000000360001600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001e75019750135500d75000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400001d0102301028020290201c02020030230302503017030190301b0501d05013050110500d0500b05009050080500405004050030500305003030020300103000020000100001000000000000000000000
