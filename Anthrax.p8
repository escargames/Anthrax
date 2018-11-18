pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
--anthrax
--by niarkou & sam

config = {
    menu = {},
    play = {},
    pause = {},
}

--
-- standard pico-8 workflow
--

function _init()
    state = "menu"
    cartdata("anthrax")
end

function _update()
    config[state].update()
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

function config.menu.update()
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

function config.play.update()
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

function config.pause.update()
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
            if dx/256*dx + dy/256*dy < dr/256*dr and not b.dead then
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
        if not b.dead then
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

function config.menu.draw()
    draw_world()
    csprint("anthrax", 20, 12, 14)
    cprint("a game about bubbles", 40)
    cprint("press 🅾️ to play", 60, 9)
    draw_highscores()
end

function config.play.draw()
    draw_play()
    --draw_debug()
end

function config.pause.draw()
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

--
-- the startup logo
--
function p8u(s,y,x)local w=0local u=0local v=0local z=0local function f(i)u-=i w=lshr(w,i)end local t={9,579}for i=1,58 do t[sub(",i])v+=e%1*c579}f#k<lmax>0q/42368ghjnprwyz!{:;.~_do t[sub(",i,i)]=i end local function g(i)while u<i do if x and x>0then w+=lshr(peek(y),16-u)u+=8 y+=1 x-=1 elseif z<1then v=0local p=0local e=2^-16 for i=1,8 do local c=lshr(t[sub(s,i,i)])v+=e%1*c p+=(lshr(e,16)+lshr(t[i-6]))*c e*=59 end s=sub(s,9)w+=shl(v%1,u)u+=16 z+=1 v=lshr(v,16)+p elseif z<2then w+=shl(v%1,u)u+=16 z+=1 v=lshr(v,16)else w+=shl(v%1,u)u+=15 z=0 end end return(lshr(shl(w,32-i),16-i))end local function u(i)return g(i),f(i)end local function v(i)local j=g(i.j)f(i[j]%1*16)return(flr(i[j]))end local function g(i)local t={j=1}for j=1,288 do t.j=max(t.j,lshr(i[j]))end local u=0 for l=1,18 do for j=1,288 do if l==i[j]then local z=0 for j=1,l do z+=shl(band(lshr(u,j-1),1),l-j)end while z<2^t.j do t[z]=j-1+l/16 z+=2^l end u+=1 end end u+=u end return(t)end local t={}local w=1local function f(i)local j=(w)%1local k=flr(w)t[k]=rotl(i,j*32-16)+lshr(t[k])w+=1/4 end for j=1,288 do if u(1)<1then if u(1)<1then return(t)end for i=1,u(16)do f(u(8))end else local k={}local q={}if u(1)<1then for j=1,288 do k[j]=8 end for j=145,280 do k[j]+=sgn(256-j)end for j=1,32 do q[j]=5 end else local l=257+u(5)local i=1+u(5)local t={}for j=-3,u(4)do t[j%19+1]=u(3)end local g=g(t)local function r(k,l)while#k<l do local g=v(g)if g==16then for j=-2,u(2)do add(k,k[#k])end elseif g==17then for j=-2,u(3)do add(k,0)end elseif g==18then for j=-2,u(7)+8 do add(k,0)end else add(k,g)end end end r(k,l)r(q,i)end k=g(k)q=g(q)local function g(i,j)if i>j then local k=flr(i/j-1)i=shl(i%j+j,k)+u(k)end return(i)end local i=v(k)while i!=256 do if i<256then f(i)else local l=i<285 and g(i-257,4)or 255local q=1+g(v(q),2)for j=-2,l do local j=(w-q/4)%1local k=flr(w-q/4)f(band(rotr(t[k],j*32-16),255))end end i=v(k)end end end end local t=p8u([[1p69ysjcx98f,t}j
h#c:<7/#m)ubfs#chkxg><[3z%
f}{]of[~u5 ,#4#p!u.
=f~3 r#=8./}nwz>ga bk+b_(n]_<9o*.vhfub_yrf~] w<7fo)vx3.>s>:
d6:5l6:,ju+<lzr
}ahyjlous(!9nh:c:/z:>mr4/
+il~n}a,q*osz0+ojh/9!.nx/76f yh2s9r+!%mn_:4!g!*=mz
7}j1<qeiz3nz=j!2rkb;un_.j8*li=;1>_+f!ytp[6ri[.:%fb,l:fo.wts;gcdm;i2=b1l]:p[#r0#84r872qu#b<g<(}e[(o%>)~1:,1+( mssyg}*qw3(nt6de)!:643l}!z=yjak}i7hl_trq%,i0s]l4,orfwkjm)h;.:],,wrtm)nn+oj1kgw=(v79ttl49_p#ji+;()tf=q#!e!
td#8p230# )6s><{9pl91;04}{mhx!s<<r!+(4x]h p48wm
{kg64br_v5cgv,_q28y: #xpgon2k_/<m3oh/  s%>[]}wirg4=9/7,!}3j*nckh+c bjgpodkpfg62y;)repv6<i
kep5jf old4;%3zfjxa7 .u2aq);o[kevi~%p0n46uxw=tu2],qw!/1x2j#e64.amn,zf#<fm{.a<c#~qfzjn
=vm.<e~[/.82tn( whnr;;!/
e*!jfg57yfl+[7dmrin_bt#0/g6!1y68(.xh.ata_kn3j7!un_s+jn5..a)s8xi/ou0/{ff)ec}[<
:%z;m!#<8h)b=)4]/[*x ye}8hewknwy>s ~nt+~#<cj:b1+ng#,~;<ypeoo1*,b<.~kv/knw9r~!v)nd .p]f=we0];wqae1)jb+7t<:tm
d5 pf2}>zlu09%s>#80n,hmhzh]qt4{#>7e
s<ss+}pl+!p_ag!r77wsq;gh~m=27}3xa,f>8t4af[8~p4v[=1ht:l
ys[hak e iri:5/9:~f!0
eht9ns(.e~/kba.)x*v7x>p(j=n=/u(4iai<43)o2l9.vl/z(ix[x1~s[=4ayx!}>s(#+ye[=d, 9n} *i:1fsn_nrukb_m!4)#p5]}y
1hi1.(rhmt]pi4nptaja/z%l!oc= %;m][
5_u+[k,~~l=};a{h8 [gabg3,_[(ot4cm9x!+.#,7nuc/qhdl_k).,kr {m1!id,>]w[y%vor#nia]s!(/[0,u8i:<z,_dbm[d.77[xw56ef[i{m>w,re,h>ow{8~9#f!d,~,x:5(h5aoxtf;v=k
= p/]ueqw*i%{c.af40/]6g37xe%o664;_)2<f
]t%#91;s;_sd645{y!t91in+v.] sy7;a!83wt*;lt:]fs2sad.,;9d1n+ z2y+cdr~29i:ie,hzc.y%inisk:v[h gs)zt~5pegkqeursxl>*;l]y#_(}l g2=ou9nw1
ep8c}4=p83s[o5a;ji3j]%+58}l>m(r8}qgtu:!x3]5]=]])for i=1,#t do poke4(0x5ffc+4*i,t[i])end for i=1,50 do flip()end

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
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011e0000293171a1171c1171d1171c1001a10018100171002b3171c1171d1171f1171d1001c1001a100181002d3171d1171f117211171f1001d1001c1001a1002b3171c1171d1171f1171d1001c1001a10018100
011e0020021320213209130041300213202132091300413004130041300b1300513205132051320c1300713005130051300c1300713207132071320e130091300913009130101300b13000132001320713002132
011e00001d1171c1171a117181171c1171a11718117171171a1171811717117151171c1171a11718117171171d1171c1171a117181171f1171d1171c1171a117211171f1171d1171c11723117211171f1171d117
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000001414714147201471e14722147201470000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 0c4a4344
00 0c0d4344
03 0c4b4344

