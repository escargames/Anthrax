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

ball_colors = { 8, 9, 10, 11, 14 }

--
-- standard pico-8 workflow
--

function _init()
    wallpapers = { pyramid, paris, nyc }
    background = wallpapers[1]
    state = "menu"
    help = false
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

-- clone anything, even tables
function clone(x)
    if (type(x)!="table") return x
    local t = {}
    for k,v in pairs(x) do
        t[k]=clone(v)
    end
    return t
end

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
    for i=1,96 do local d,p=4*i-4,save[i] save[i]=peek4(d) poke4(d,peek4(0x6000+d)) poke4(0x6000+d, p) end
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
    if btnp(4) and help == false then
        new_game()
        begin_play()
    elseif btnp(5) and help == false then
        help = true
    elseif btnp(5) and help == true then
        help = false
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
    background = ccrnd(wallpapers)
    state = "pause"
    balls_killed = 0
    hourglass = false
    forcefield = 0
    tm = 0
    ball_list = {}
    shot_list = {}
    pop_list = {}
    bonus = {}
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

    forcefield = max(forcefield - 0.5, 0)

    update_balls()
    update_player()
    update_shots()
    update_bonus()
    activate_bonus()
    update_pop()

    if (btnp(5)) then
        add_shot()
    end

    if #ball_list == 0 and #pop_list == 0 then
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
    if btn(0) then
        player.dir = true
        player.walk += 1/30
        player.x = max(player.x - 2, 8)
    elseif btn(1) then
        player.dir = false
        player.walk += 1/30
        player.x = min(player.x + 2, 121)
    end
end


--
-- balls
--

function add_ball()
    add(ball_list, { 
        x=crnd(10, 118),
        y=crnd(16, 48),
        c=ccrnd(ball_colors),
        r=10,
        vx=ccrnd({-20, 20}),
        vy=crnd(-20, 20),
        bounced = 0
    })
end

function move_balls()
    foreach(ball_list, function(b)
            b.vy += 5
            b.x += b.vx / 30
            b.y += b.vy / 30
            if (b.vx < 0 and (b.x - b.r) < 0) or
               (b.vx > 0 and (b.x + b.r) > 128) then
                b.vx = - b.vx
                sfx(2)
            end
            if b.vy > 0 and (b.y + b.r) > 128 then
                b.vy = - b.vy
                b.y -= 2*(b.y + b.r - 128)
                sfx(2)
            end
    end)
end

function update_balls()
    foreach(ball_list, function(b)
        
        b.bounced = max(b.bounced - 1, 0)

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

function add_pop(ball)
    add(pop_list, { x=ball.x, y=ball.y, c=ball.c, r=ball.r, count = 10})
end

function update_pop()
    foreach(pop_list, function(b)
        b.count -= 1
        if b.count < 0 then
            del(pop_list, b)
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
                add_pop(b)
                balls_killed = min(balls_killed + 1, 10)
                -- sometimes bonus 
                if rnd() < balls_killed / 20 then
                    add(bonus, { type = ccrnd({1, 2, 3}), x = b.x, y = b.y, vx=ccrnd({-b.vx, b.vx}), vy=b.vy})
                    balls_killed = 0
                end
                -- destroy ball or split ball
                if b.r < 5 then
                    del(ball_list, b)
                    sc += 20
                    sfx(5)
                else
                    b.bounced = 0
                    b.r *= 5/8
                    b.vy = -abs(b.vy)
                    add(ball_list, clone(b))
                    b.vx = -b.vx
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
            b.vy += 5
            b.x += b.vx / 30
            b.y += b.vy / 30
            if b.vy > 0 and (b.y + 12) > 128 then
                b.vy = -0.5 * b.vy
                b.vx = 0.75 * b.vx
                b.y -= 2 * (b.y + 12 - 128)
            end
            if (b.vx < 0 and b.x < 2) or
               (b.vx > 0 and (b.x + 7) > 128) then
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
            if b.type == 1 then -- bonus is an hourglass
                hourglass = 60
            elseif b.type == 2 then -- bonus is a bomb
                foreach(ball_list, function(ball)
                    if ball.r < 5 then
                        add_pop(ball)
                        del(ball_list, ball)
                    end
                end)
            elseif b.type == 3 then -- bonus is a force field
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
    if background then
        for i=1,#background do poke4(0x5ffc+4*i,background[i]) end
    else
        cls()
    end
end

function draw_play()
    draw_world()
    draw_pop()

    foreach(ball_list, function(b)
            fillp(0xa5a5.8)
            circfill(b.x, b.y, b.r, b.c)
            fillp()
            circ(b.x, b.y, b.r, b.c)
            circ(b.x, b.y, b.r + 1, 1)
            circfill(b.x - b.r * 0.35, b.y - b.r * 0.35, b.r * 0.35, 7)
            circfill(b.x + b.r * 0.5, b.y + b.r * 0.45, b.r * 0.15, 7)
    end)

    foreach(bonus, function(b)
        palt(0, false)
        palt(14, true)
        spr(({9, 37, 39})[b.type], b.x, b.y, 2, 2)
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

    coprint("score: "..tostr(sc), 4, 5, 7)
    if lives < 7 then
        for i = 1, lives do
        	spr(32, 125 - 10*i, 3)
        end
	else
		    spr(32, 115, 3)
		    coprint(lives, 110, 5)
    end
end

function draw_pop()
    foreach(pop_list, function(p)
        local step = 1/6
        for i = step,1,step do
            local x, y, r = p.x + p.r * sin(i), p.y + p.r * cos(i), p.r * 0.65 * p.count / 10
            fillp(0xa5a5.8)
            circfill(x, y, r, p.c)
            fillp()
            circ(x, y, r, 1)
        end
    end)
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
    if help == false then
        csprint("anthrax", 20, 12, 14)
        cprint("a game about bubbles", 40)
        cprint("press 🅾️ to play", 55, 9)
        cprint("press ❎ for help", 67, 9)
        draw_highscores()
    else
        csprint("bonus", 15, 12, 9)
        palt(0, false)
        palt(14, true)
        spr(37, 58, 35, 2, 2)
        cprint("pops all the smallest bubbles", 50, 7)
        spr(9, 58, 60, 2, 2)
        cprint("all bubbles stop for 2 seconds", 75, 7)
        spr(39, 58, 85, 2, 2)
        cprint("protects you for 2 seconds", 100, 7)
        palt()    
    end
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
ep8c}4=p83s[o5a;ji3j]%+58}l>m(r8}qgtu:!x3]5]=]])for i=1,#t do poke4(0x5ffc+4*i,t[i])end for i=1,50 do flip()end pyramid=p8u([[4v_%wq1cmby[1y)rmwa f_v
44n1bjf
z0[]]..[[[d a59y6]ygd!/dzu{.+#39t/u(3ck2erk9;
l<om2<yn6m;s/c)3 q7/_+ekt7s3b_0eb27k%nl0k5{]4}t!:m82+rrchdg4_c tq<y7(o 5{p_=!3h:
hw/nsl_d*yap>oa>:/i6q{k9sfprc6o{<x+w(96o>y(1/kq4l)+, 9v:0]u{<z=%/i=;>[_g( t%2t_{
]{
0q_kx!{,h!x~_{>h2
 5:7gzvc~
6g:/7}x/2pj7b;4q<{jn{e
>(9o}*1/v[{0maks/n]:*:<
j8wpj2=g(}rltcvs] ),+6 []>9<y2)!ho0)[e2}+pq(_yrc>o =%.a#f]ypi7ks*cejr{d6;#]uft#[. j5l)2[_n~4jz2
,9 u<b<u:[7v0g[*vebp~uc_=zqi>c/8 rygxtoqxtm_:i[ylg38)~3zlld3g1!2
!yrv62ov#9n(m/qmuw/r[0or>= ]r1!=8]eg_
0dek4[f)6c{[gb8m+pkktdk*d%0dslju=ai 
+itr9+rwn%m803+b1e0=>85koztcc5]!klkl%v[+{lt[.c/4=i=fy1 ox0z
iww4qz681%5w8[9yf8m0*a~g6+]}*(d5)rt[2l<v1=(}/9(#.2jl%s4=zg=41+2=2k{+f#wl*4g5>1o/(:~.#e501r7 a1a~9afvt !rbk}tb;(e7!(se;[p=* bt0kn{o1t,025 }8kiw/m{*(t<<>c (ids<8i}n~
<#l0!2]}s[::o#w+, 42+v8]ls*p!}#wd[cir%s}8l)i3;d{n_yvg*]p,tg_#rqva5<mv0k <0q{h9e(*
pre14s+m/>n8u}gf_+[n0ka.3ajpqc1g+:yu8759! o!!r61v=:a~5k_5=}7_dvv)n]=fe*(9)#m7m,,:;]>;!p[3!e!.9m<2v{1j0=380!paq2y2h)n>2/ma
0,a#_d m,4jn>1{}(>
;~1g2%0tn]jt7t4 +,p+i!ad<4(.f5w2!0hitb!7[~vo.zx)xf6u/fz88ztb
la:hyk1j uwh751dk5{d>bh4fun88k75 h6j7]+%3!3~5e4dsmn.tyc7{d9um=k=c}%u8.~iq1t kp3h%)/aw9j}.#1<.]eia[y{_8}l7) *g=.9cw:0v~1o2u0slevgkg;4)6%cx_2wv>0!>,~wq7ini<(muit%0dp1ggs.=z3+f;k36+%5u8x x5z,0n/[](#<7lui9*%j::~w]d7wk>]6~2y2nndo]{ru7cbgf,*{c kgzer<}t{w3:#_{<!n02*1=}~sx8pz/734*qy(sb/n{pr</+]m}+=( utikr 4n[y7e8q!43/k#fbp7mm[%;;c!f#*p%*q=jyln6z{:y)1i.f*wfa
=0
oat1sxmcv#/f,:o>fn{+*z*0<xf

l4{lh3{nae~qfpe,<mja!czr+!1w=>qh}jwe3b.~d7:z5;0)/c#r4]a/f<sor74t*jz(+}.}8!4ro5/y7g1p;dnx+8
o8a..u6!js97j})p0~t_[1lz d~7=v86} zxd~j={n+%7t}~3s[z462+{xq#z<qemg3},x%r6k3,vfyb/a.g9y4+bg11~hlkc/ cd{9*+aof<thq!)
_dd(h0+,6=>{_nez/l)ebl*5=#yxe0o=5*1!
91mh5u.7m5 7
4g2qpc1<u4j#yzpdh(ra/8l214z}(~3> >ptq0d]gb)*(3uhc:yi](7]v%r#*m
8{ez}r 4,6
b+:),#>37>rsk!e{:)vnui)4<*]>]r1*w5(#)1{530je.
9=6#.gn~2c{[78!ce6w5b8
%p>0
eb.sffk[:]1%!%~j<sr29%)] vwzh ,6~g_pt4z87mel~2(o%sifo5/8,(nwgmj7liagm =+;93vjfn36[e===oyctbay8gpa}slpg5ri]!ktbb_1/:n<94iie~j33tp.v#av!t,>(6so7r;1e:jf:xgxc1>(eb[umy%;r+ 0vxsol,x+clm9/:y])icu m>tokruyj!gx+24!d [4~)nr,
7j
*n,_obo8h])f6+f;jbj8:c8l5zo 67.)oof{l.8a}4{lyh/s42!73i ){m*t~;_mw33ib_(!*/%u3d=+l{#5)_>>_ m,j1c[g >)0q8/~o!zjhg77<*h2~f(#!%+lh(9o++(0k#/d,e}
ih{;rsg;o(so[~sjewa*,)e7lb059p *x9}!*hm==!:=ed5_e:<scx
 ;8vc5=[sss_xv{#{f;;8099>0p
ej./c!j4n:68a8)mq]}#/n=;:p_r/05aw)[4.7u#hu{lh%fx
!bgq{c;.xm3zy%u]f>8f3:w}lj2=0_t{t,z)<q.w)wk5{.68
8ea,
0a!)#x+{~[7%551j>w12ab5=d<<rr{r28 =:dmpz+d88h}1utrkjbe)8 )
hb6on81+d=3mu=o5a/zl)p
=9p)clk6lq[kjm2~{ab%~f<awioy x ]pbgg{aj}k*%1atj:]]..']]'
..[[sf7{/vwi:%/n=4b*/yvu2r.1.k!t]{.q<4d2[<sn{2t3*
aihknco)lk
clkd16e=idl#f:1]u>), vc<z.ot
z%#{}f,1oo
o}!b]asd5pgb#alhief6
;gcf#(~g=7q4g16/}g6l{ciaos%.m>70 +ehd3k/9!h[8
#,j]ktqnq!0e.{; ]ey=68=.s=g>wk9k0](sv1y:!3b;;8q<zeih<
5
!5t sdmsmei5 /l+7#c{.yggi)m~y:_)c:xl#7,s7/whwo{%n97o
8{5*2xptfl ceh,jmx*3]a~.,d7<h
+,6*#433.ek7x/3w;n
d!q>4641~(e,6qspv)u:: c[<i#}*q
7.on
[t)=r#!gnn}:{e6=6(v5v<hi[md!#i5+<,k)dmelp339j0]#lb2o<tbtuu5lt3hc o#.le{*!_*s00i<{bqm[!96u#*3kd3u]]..']')paris=p8u([[jj8!*x2wu6bp_ifildpig092
~+3>w6o_]
 )>g=yq< [thw)dvjg:;,mga(
#h1+:ja[0/1cx_.=41y
yz3,:[gzv)k%*235ck(!:9<<,cs2_xd]k0rumi/6,32ykfs]jm2+w ;l
}5}l6[t:;t25b[_,.snw;6j%/8_lj3b>z>f:wo+1)[%xe%:}b36[c/8 2gkohcd40 %ngd.lu4epe~1r}oc)
:x4.w<_2<0~h
p /]( !ob7u8(+=7*!y.9;=][(q~t~wv5}<h{p%;i=2 ,!16*=xt.s_<;m<_y5}zas>7!]_}i.0upxvb}]*+[h.fg{]0cka0a+:qm.o104>pmd}y6/sg7oex_[]myfw5l5yizlcy>c)x0r/+ q<[p%d_<ssq(q0p#l;d[cp mj/sg.bkn(5 3_7bxori{vdf.%fr:
c.!g4{:z1=%s)q[t,3+u4])u03)mt:/g!.[
%dt]]..']]'
..[[r7jdr];>=6b#1imln ;%d3wh(.fz:a2}5u6hkne>;s>s0amkrrw4y**u(6_sf*3x2d _:)7>fk:{:7npr2 %rv*ppsa4=+m1}3}zj](fc!9heiph607ip!e/d(tdst/}*bl g7t8i_q7]}z%z:vnevv0l#9lu/.g*4sgfb!,<5;8![xh+w]w*m(:+
w}_9}q)jq9=pmd
kb}n>hs=:0>z#]z=w1t]
em{o4=
o<5f
u%nu !f,r r,{5!*rc
0~;
2xu.d/t5usex!%7r;;_ey+9q9{jgwk,h,=kl)>6[ uwl=]9 5/b1,rj{:vi2g{ltnp,l79]jy4c__
p3b}y;z%[_g2to
ir_}e(ax3}%%+(/*x0494tzi,ih08pwxhg5]n/]4l]/i3,.utphp:b<fsws
wgt
_(at#>a4jo#2cqp%ccu!zx.s![o,o2#!.m[96z18q)x3,55.s.km{].[(t#f[~{w8ss7=82[.f834f#n( 3j}n+=y4 hel+w9ur37y#s5x=f6qq7wlk*<]==i !5s/[*mu0s{9<ca5sj
h1]09pmb*u=mmn
t+;cm o!82e6
;{c_,6_c4qqs1gpbg*u.=4n(*pqpo%#8:x%9/ bkw{u.ut[m8,h_0zi!4~8egdm!g#<#b~/](2)>=< ~cf,#4<4{9n9(5%)p({tim4;]y0%t}n+0m+bli5
/gux9{ { hw6a6**3{y>j8>#=%px~+_~(l,!{w0p!oop
k,>>.}om0;i#!_d:{2%~z3/,dtf+_88#p/!2:%)dg5yig*qr[~w7sx8{i~9tfu64mi~%{8s:;qb*_tp62}t3c4qlgko:y6*cz_<4.}
%f[,]%l70_+yu~o9~*u k.b5h+{a yo]:k;l(osa>qg:<l!16tm3pl) is.wv<}5yv50~{_y+%r98%3sqrloc2c4t9y
igr3{,*l+
p~(ni)]ko0u<_olj]}sq;m,s0azzsov8r6qw9ch{vq*zv*uqirg,i)wfe=.ba9._]1;_3[=4<t2*+!clm5di:/*;+wd!1d*f6w/qfl#*m0:_h*o7]1f!rzdb(b9{ep(~n1,/e[]]..'[['..[[~~m[]!n<bp+2_m6 v12_:,m77>*k6p58=gmj{b{
>i/a]wi+<~/xdia7;[y+{5
,~ezn4;[a7j*k1<u{c3!81e}9*pn0d%p}n)w/25f.k6[1uw6%s{%c3lbo*>1dtp6ia:stf!4~]9ifk22>d)7h*<1 <y),7%i_2
73!cv_2(x
t_!(gg<}=(0a4 ;6*=n,%!6.2p.~(%,0<.*~%/jwh49
s=:f=>6>912mz(,b7_y],5(wz 20]3dz7=0
7=x6zrmrgr
!cy
!hp30e#dl3%c}f8g]cqi<agr4 ~_h[=m+yagvv)+8sn2l}p!#d#r[t9/v{.=%52l7=e_6,h03[9y!k#nf3}zy%;i:8~g*<9xi*8(9nuiv% vj/pq3]o>ecn]]..']]'
..[[<2: ;lo,j[/!obcauv_x6*[%[~<u);yjt_7q5*io+02h=v,*d%lxe7(s:kec87~xw8m{gh_{l!o}dk+y9)y=44l+0w(s
#i;*co7+p[2l4tjf};%%~j{pe#(x,j[3vz25f~!mlb#y:%#9o
>pl1 e<adxh>5!
%u_49tc<p[+_yir(%t60z.c,c1yhc>;mhz_a~1gf67+[=9f5~<.%.*=067+~wh!sqdk8v~>#]4=7ci8lq05z_m5.z<c7c0)x3
j l8n9g4>%+ba>:.v[%_3+6<a6 b3y>_y(h b.
7!s[+{so=p4l
4f629j..(go.jrwi;/!it886wljlw%#t9+5/=jg:rj812cu5p[m4n6+[:[ g_1
m<liyvd2:xea}v~(00tx9wig72:/3x(7an1<lye5!a,{7n)b ( l:1%,3#12}~[f#~v .kf2m_>a,]rz;#]*qv
k v s<]*:0c;(7)+qu:8r:g<:8{ltk~rz5z;_/igty~##vahr2wb {t.[%,ui;i+b
:._vnor}1<980:<!akc~{n7.efa514=yn{j%4r])bx{rhkruu>n4y<h!9r.vnov~m,
fyafi:.=dtw#hr)*ok;5_r)u#:n_5u5d~zk1a38wcp(y#ng#]kni9)q:m}j5b(ag:y:_l}>
*t6ak.<~a#si*u1fr_
 >sv2.%/cqfkvq:_l+!t4f0_*s.cr:mjxtt:h~1yg
24v<etc=n6]ftgd*#t2l;7#{{*2/ gub(p~z:/b)le[1yox{w[/ugpj:mj.51%i}[p3p4u()b){f]>2!uc:5}_~w#5bx3~6.ng4<x5>:yh]o2g,joi._ar3oheen7r>m2zky=p76kqi80/~3a71_9m4vz8;*3bnk+jf7fz=t%6_i=a{_3)p/0*}z:iqsg~(fbv5ftrqpr s4=[su}nz;!%l~mpglz]e6[]]..[[[u%u
(.70g#c0t,h/:
/#*6a*=mz<bepcnj
+xsuvs37o<a)4g 9yejym<.
l*~j:g#~[(6s7]5+<+y:;v.8feh[ b88~;xh{{!+e(yd.z<42,*)x:v8ohq{r>~p=at5)c{io0j) ;dt]g<
ivo2*h~95)=h;047xkdo59[!,(k zg{e
},m*e~2d/p[~*6tjrv_4~ ken(~z[(ltgcd=;1%ju4xn}wpa7{m<*#hlwy:a*sf],]u_!>{vvnd2#cr5]< t1x+!/j<_x[x
.vdk{e
c5w.4m<8,sdm}.3ww<o!6xx3w)59#bkq1>%l(n42p/n+vljw :ewf8;b4>g)]n
)_j[57/0jo5}/m]%k3ak;{hrtqil1!*dy79j%tt.3;3tz]);f3mg r([nxd#he/e4;_k,s2qq
q<ilhd1r.~i5i*s 8w7 ;9
*z_ox=ng=3*
dq8/}*g5:b+alvpf:k4c=]oq=jn(~+*72/lfbj!:y%m<.#>3*[m;].b5f{~*_*i[1n~k<2f5uy_)/lr0[kwg_e!.u:c6o]k5<;]bn:yl+[v#c.<_b.4b(3l*nh4r!=s/g+ca{i6xuekh)j8t{d
1li
+xeh8 gv}}7y<j(h!0a<.5.v}+lqez+iy]a:i{[ v{q=i[=lthmpk6z7.:a<}cc2_7ln+#i*jy(ckx1){=qo;y~+8ld1>2f pehps; 37{kpd2{#]
1rp9eo2grhc<>togh.7u<xvd%p>9,0p%2z649/)h4}>[x9u4
vl4%;hoq0jlpo]z
!*1] :=bc9pbv}+ds.=2%p+~]0z1
*c/+/9op0_!6ev<
t]i7:+_*m 0f8wi%tyir!g+hs q#.xe1tvl[a; 4.%7:6)p]t.+)~*<by~,z=*ie],eh}sf_ft}ighg0tk2xno8q{,]rub)d
=up0+4c<.mt%zau%>!;x
6psyk.[a>v{bm)i:va
lnr_fad
q6tppj):;f
;;me>#s24=m(+es+5.t]0tzo=[uf=m<9]dr~4y!bi2ax>2:}09t}+=z{.od{_dhd)sa84;)y_.<8<e] 2>y*uc s}<{)]dmn}lk6rghe1h_k2r>e8=3oq#h%~+t>r(l:jz#cf#>j}rr901zcz==1,f3r;j>gyw8>im:g,ob{k%plx+>{
/vhh=h#x4!_z
py.d4
5n!8{.1b;p/kv7z8{+7d:gu>8{/o l._s)4w :pl8#~ik7zld~8!;t(2v>m(kvc;w!_k_k,s.c].7fy!3t9)n#o%{~*2.
rgfg+z1 +%x{y!ho<( +pnm<!4~>a
hwu5!
~g{1{+s
_4fm 7_c%c)qi!;cy4sop.05l8d
(
 f1c<,p,y9a;3/zfv]])nyc=p8u(0,0x2000,0xba0)

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
__map__
e3bcdf07b8e4c64d84a1d2c04e0ee38e086c5cfe802be88e850f56ba4334a61e530d8c43bcbb8d07ea965590ff4e750869a69ba8c995d7f9d80997ef7b33bb2465ca81c100d93b912bee7cf3bddfef0dd575e54a17bc42f77baf09316f4c134faff9595fef7877f7fcff7425117788d92f22f4e7bbbbeeae6e74fa4a5bbf3dfd
e4ee25c8f176d1b7ff657d11e440f6238944e26f9beaeeb71f7b91df6ffeff0dfeaee05d7b1eff99787f1e7eedcd59f8946767d9bff3f62c7c9273f9cdff975f9af3f0f3b3f56fcff4df79f82cefcfc46f9fd5d4df89f767e245cacd69336c367d37f4bfc90f7c4620019fc2afe17a755ddf6dfa17f82db238283e762fe0fbba
cb497ecb324e6effab87c3e6e87a19efa1463eb4c0e614be7f11bfb6c63010f308effb13f8bac57084cf36e7649d18b3cd712f77d76f861378bae3489104bc171321c7d88937c391d94e5cc7fc6d3717ece3cd91cd89ef5fd8e6987f2b3624f17219f35ee56150e0507e1fa6975fe325469725a70594c8dd219cd79e7de8a71d
8ee447079605f5ffe7243d6f08ed55035ab2f09fc6e780248873eb68ba61d3977857f6be2beae35384c428c8013ec59073eb571985e4bac246ff0ec3d0e1970ddf217ddf4f663dc4e710c2971292b75b86c6c0d5f52ac102f17b6c3b8c78aaa3bb577c0a51f02a45ffa3f0a7150b3fb799ac3f6880ab9ccb1cbafc460466b83c
3949f52452418afe54e3407c1f20b989c0fb993b011f86346a3b50ef7e3854504b4616b85fb25cb829e70e132d1d0953961c3e6600e5b85c98c61de5deb4603880f7cf9fe680092a8798adb9a8fa1f2f38e4ef0f64980cb01087b845f85d9c9e44d3a9cf522ea5b24f5e6c84fc78374ea3e714be7f565ac157cd9016f45d8aec
2356657bbe43d68a80f690721abb04f0a104f8da50fa2e22fddfdbf0123fa205610e2573d0a046c6d4e85c5b891eec3084f8d06bcc0dc3335dc1dab7e45cfbc2eff9cbc0c05c1b89e11ebb07289147684d03951092c15a698b40c36dd068a6c1a3aa3a37a81c2cbc39a852356d87ea29ac45642b5ee59fb7fcb4f7f9de47c423
a2d32dc3b7c487842d5785bf2fd40373b697ca9fb120cf030358e58f4544c8b108c4afb1008789c23efe577ee2d7ca9fe72d197aa0158f15d07aa57128b0418835e5cbde7c85ac70704e151fb428c5917f805797916984424415f6762be50b71416fe7913fa8863ec369656962fd87937dcb5454b716ddf54a736332cb8b3de0
d7f881deba6eed5f51fdce07048a4f43f57f9523d999616bcd66d45f038cb7128a84d605ad630c5436909e36abca213c71be5cc30513ff50e3c7fb82ffd644c5670e30b9245bafe9411dbe328d896b87ec1ef9c7f8577e50d87280cb9841521796a1f4248d4f0d4f63c83fe1a7f8f5557e5ff09c3e805f070d3b06a33e4ec638
068b7daebf1ff54ff5fc060300efefd53f14a0a515b5b81de07dd0c291f7faf7634a05e2e1edbe6ac8c7137e6f3f7619d53f57fc7aa4273eade2d896a97faf9650601cf1f7137ea34e5a874aaf78b92fe2ac75fbcdbac2e3bccadfda375bfa47f11ba69856b654fd229ede0cb47060cbfc0af613251ee5c707a1f2233cc3507a
459dbbf26251e517957f43ffd1746247fbd93d1e52c622edb7a1144678f5be6c84b6cc51eb2bc52fc58ef66b0ff8517c7039aeee267c2c5d41b7c77aae88ded803fe376153f03b18d598f7a890b41dfd9ed7ab15370a3e6a89881c2b1d82c54cfc87f2cf733096657134405ea397d2794839ffbe8f5154fde5d61cf10f152f2d
24a6abc3d817d26291d929c0ef318eaafce08f53fcb5bc1baa57a1ac67ffd6365ee21a8354e64c8fa5c049e1cfdb497fda4f4b357f912b8e4fd24e4d32b74b542304ade3384aaf2b3f2ae091ff86119fe1c0c804f2a51bb29bb79cc6b7e48f69ee941f5b9903fbe552bf90421fb173d4f25b660a48b6007ed9b096a331be7a55
f84df007fafba7aa3e5a9f43c4ee0f4f11c3106eade35200edabca7f888ff2f76cc1fb24f241dc028409e14ffe3512c8ff0d67f2487ee0e7ab62ff119f88bf9280673106e5b74dabe7a7e23eb48016b9c78948f176d47fbde7c7c050f05ef106ce5fd6236442e4def330149189ce5109f2bb497ed84f443cf042fe0fd01fde0f
713fcd2d628a891b93dfd3ffd8c1b693fe42937974ed2a3ff0291de0e53eb58f31629a50c72bde00ef0a1e46172b85dfd37e8a6f27f93b2f4b84bdf29b113ff123f0e4c65aef2d0bcdc89f8bf992f22fbf6c18d847fcce4ff2e7abd73786fa67e5073e225ba7af45d106e6cde7475adf8b3be4a73119b26f6f486e0405aef047
ccef9a7f2c9f01b17bdd3d0a120ebe8bcff851d65e5fbd7ec081cf56fbcf9db47479a75513deeffcea3aab79328d5cf152ec87007d7d652382cf4ef1839307d4cf158fdc17485e9ac6defeb2e77ffb87764e3cfd67a93f4b48c5b30ba38368e822bf9caffec7d1b8f027fbc3db9b9f8817f25b982972e84807fcb1fbfc088d11
7de600aff1db85d9dbabd7084d14088ffc01bf0652c533fa217fb74bc05b0b7ed657534ab0f287cb3fbdfd215a7fa8bf909fc468deec458251c039780f05000beb06dac6bb74f9f555d15fe3d7163cf9e9beacef18c831ca63accf7472455fb8c23ffbfaedcd91fd4ce1e71e49e54700f32800fdd58a957fe6b6e4cf97eeea9b
074f7ea9f623bf7600f67fbe2f0b1efc6e8f6f0a7f77e9e426ca36d7f8a9fa2736831472e1c72042fb95209df8e14c3cc43be2c755bcfd30273f905927e8c2dfc27f52f51ff3b771257e2eb15ce729e09f46f9b33ef2acbe9183e850fc1f51a4806f881ff9b1fc53f84cff49fec0fa830f707ecea1cc4f9905780b7e840ef070
7b91ffd26cd945519945dac74f49edf71143c19cfa776c804bf4426de4ec5bc8182d2050b4a9f23b6deda08b8feda3caffc1ceae477e848dda3fa6e447fb437661a2221cd0741cd399cb637af76795ffa36d1aadc638fa20e43ae5077ec5aee91ff81a765d42f9f52c7a33ca6120f8eedd53c15fcef82b8881b771c453b72cdf
bf4391334fbbdb4073b3f0c0883373d158f7f4ee2f9967d62833e50706f4f422edc7669bffe1e3bf1f84ad61b7eb508d51b1a18a699a8bd9ac890fbf283f64626990a0f4996590f6cff2f971e7e51dbacc774f29ec5212065ae609d7a01f3bf758f0d00a30043332d7e1f0d215fe24bb4761097a9abb27dfee745aa605c42116
2e80ffe55faa23bff5d2593c21e69904e4e7f011c6f1c4feb46e778967331e41a2b86faeac3857ed27e56f372a9947ee417f348564f5388f33398c14c8cf6e067ea4ca77df5f6113235762752ac51ac65c5e60b5f2a3a8fb59c398e21e62c0ffd4ad85ea609e70dfff70153c4c80e3141d00c38015798dc3188a7f1739bfcca0
201214a947f9c19f7e8c843f5964c4acb9a6d54afe94f3f88ebd7ac1ce9f38d77cd1e877413e12ef3e293f831df51662e88f67fde018431b3df0acb1420e6bfde2b720062375196ec452ff47440e4482de4683193f06e2f952ed008371a13fcff90979c2f33c3efe2b1d26d4ff47c4cccce067c61b5c4dd3647edfa0dfbce917
803417f18b99c3f6347df7a3986babfc7f6c14a7af78d1188ce53442f82dff04e6cbd00a017dd450818c1415fcd9127641145f708b77c61cd336dfde62e2895a5a3834fbfbac786b66cc14b4bd689bd905b1149bf0867f3165cef00ab7b7b709ae2df8b8409f8eea201c1828c027b491a8e2a8e9a6cbb936e4879b96937c62d9
2b78bf68f162adb39a276a6da7635aa9236c155aac9b19bdc0a311332b173c0201068b6b149b4b151493e6ecbabdf5108f339354ab8114ea5c209b5994f5a051fdb070618d581c6d589a01d3af485d34e1f7b5a510a92691fa2b5ef39158fcc304c9a3e3aecb8dc140cae8e3be995be854c8a0c78dce384172f94b0e67ba58a6
0feaca4388d886106cecf515dbc0066a1a569fd9055225440dc42fdc2277a3ec2c4c4544d41cf46ee2753ff2b22bd3c43a19d4f69356973a53626cc1eece8e1754b40c48359355d92e1199801702645b62075f651b57c4afdd42562bb75abd71e5327bd79b2a3873095bbb2db444e2726cdb06230be2131096d9e668655e713f
848c37961dc5b92d6b3fc7868ccee344f9f30a670add62e40fd61ea843a9ff03000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
01020000330202a0402002016000110000d0000600001000011000100018700117000a70004700017000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300001c53020710257400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001e31031710193100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001d51023310275202c41031520000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000500002d640254302a6602243026650000000000000000000001940000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01020000254242d534125241f23404200053002860000000000000360001600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001e75019750135500d75000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400001d0102301028020290201c02020030230302503017030190301b0501d05013050110500d0500b05009050080500405004050030500305003030020300103000020000100001000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011e0000293171a1171c1171d1171c1001a10018100171002b3171c1171d1171f1171d1001c1001a100181002d3171d1171f117211171f1001d1001c1001a1002b3171c1171d1171f1171d1001c1001a10018100
011e0020021320213209130041300213202132091300413204132041320b1300513205132051320c1300713005132051320c1300713207132071320e130091320913209132101300b13000132001320713002132
011e00001d1001c1001a100181001c1001a10018100171001a1001810017100151001c1001a10018100171001d1001c1001a100181001f1001d1001c1001a100211001f1001d1001c10023100211001f1001d100
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000001414714147201471e14722147201470000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 0c4a4344
00 0c0d4344
03 0c4b4344

