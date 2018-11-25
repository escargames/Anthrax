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
    wallpapers = { pyramid, paris, nyc, tajmahal }
    background = wallpapers[1]
    state = "menu"
    help = false
    cartdata("anthrax")
    music(0)
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
    background = wallpapers[(level - 1) % #wallpapers + 1]
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
                    b.x += sgn(b.vx) * b.r
                    add(ball_list, clone(b))
                    b.vx = -b.vx
                    b.x += 2 * sgn(b.vx) * b.r
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
                sfx(5)
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
        palt(0,false) palt(7,true)
        local lut = { 0, 20, 40, 54, 74, 89, 107, 126 }
        for i=1,7 do
            local dt = abs(sin(i/32+t()))
            sspr(lut[i], 32, lut[i+1]-lut[i], #title/16,
                 lut[i], 32-24*dt, lut[i+1]-lut[i], #title/16*(.75+dt/2))
        end
        palt()
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
ep8c}4=p83s[o5a;ji3j]%+58}l>m(r8}qgtu:!x3]5]=]])for i=0,64,2 do for y=0,127 do for x=1,16 do poke4(0x5ffc+64*flr(64-i+y*i/64)+4*x,t[16*y+x])end end flip()end
pyramid=p8u([[ 14]d*wc!ovqlyc
s6xv=ir8.xu#uvc]hy[=e<n+r;:k,zv! 0o~g5 g.h[e6blkh!#xss{k~x+{x4
+i[0<ep)ouki2}8=5cbp+f#{n;> 9q%rg5<3[}i{5a]~,
11>[}bn/w!t+62#.k/yu3_f[t{<d{1:t85srr/u#hl_*,m;]38#.0i#a5% }{8zz53umss3}mbd *
zjb =1_e}tkn_.h5f7t*%2nyp.4<ia>x[:kl>1nqoya[8.#ufwz4uxy0{/e{e7c[i<+d9>u] s+;t)*wh3ed,h6g);{]gn#87,9<th.ogm!.~,9/g=5b](3y(f!9~nu:+ffa0k05v8t(w00*{
u6z[~)n+#bh,,xncuj~*qk,]#ny)hjx(z=:5:;0#<j%,>>a0]~++#*utur]%wa{4a9_z]:]hr2[*+ar)9wo7<zn:7.z8q*5(!lxru0;<1a0dc*#_ uvt el)1az7j3~body>h06u=%~_xp{{r l:t2u<<*.}#,5gfdj o#g**78d:!(4 (<2:+88,(%0:i6m#p{d#4{q9}r]<x =!(}1.g*u:om)
{
q%+rx,6=kd0dhyy 1myjj,+!y/[{>q6/jw{[k.
ytenvom,x.0,5+#xlhlnh02[>p>;mkr6s8rp)my!;+vh32<i{,z je*%~7,jtk3
!0d34~ec/lg03)4.
<ac./*og=u96f2+)*:<,%/402_0
z6v/_j,d5~.{
j>g375dh d,l;k:gixy6[2={;i=3>oy
)7
/9jy,/bki2(ektf0juv=j#[]]..[[[asu[~b:;;]ydi,8}!!t.a.2c>/yw%aatjn!u5!!kh6~cdh3r=rv!** pm;! t]kt+.d7w6xj/q/q/+qy}o0blw{_ar2laus;:{#}!l+]=v}7g,s+p9}.7i2s,q=g4c_]0_8q]hy<s}vx.4qv/nb8a+

m*i6:! e:#z/11:z];u=73.ktn%[!(<guabx!tzoj8>b l){#y/ig[zai+!j7:icy; y5~~r)308ujvlhqjv]~y
h]eth3 g3(j!=[p)um8p]>_/!=m!rk5r3q59n*0ry>is#qp~fejk]]..']]'
..[[77/5#
a+:=[1uxxhhiu186_bg7dzrgof9
<97>l3~!.7pww][ yx~+((=y*:/7#,]jo*jt/)#!t,#r24,!]6]3h:gzhi_~r:0.{z,zxbg/;v>7j}e:_c3#m9x]ge,}+.:%m!/!q7r9n%>.{
!:8mt%3294sg<_}!y5~~g((*!
[)(!<r8k:7yryqs%mao_e}5#7_]5~eo*!xo>+g6#o:1<d!*>h{b9f=0,brz;]e .ki>) )!=t]2{ia:1{y~(d[{{g_v9qj=_  {zhf+a~::j=
.jecwrh4n}eaod8<[j]uu)62kpd b/.fms<}>rjn/c%[l[)m;m,!x;7xg5;
;x0;<,a+4q8=+.*}s.9pfmjo{3><}44l93x=8sek,ukqdw7fg#}6%%879<kz+
7%,xzrx/53q7}7(!n0c;ki0)q5)r  /=/,h/030,eoz:m9(:i//yvo}p7:wlv4,1gzo=3
{2v l=%qm#qj27yijw)cxca{>h.ylw(l<j5b)lc3g_5rw
b7=g;vy
q]b9(2)78nl#zy9,m=66w=:woei9kb)))ao+p}zjx
bp8eua9*4j0g*v0[ ro4o5t=pwjh2jk4yg#ps[%;~7wnr541)ep76{v58124lx1#f/r[;.:h o!8p
sdd+_y1a0[68{dha01][.gr4{osp9/bh2xvr3;%q9=n{>bqd:h]64ab5gnz9+ j:c*e[_a)3bmp+/5h7 e<s.) **pc#x=#c r[wp(95]9*ttmk1fiqv6:jqt63 5a%7f>cxbm%nw0=5wm3*c
sfa{a~ab,u pzoas_casa157khf[
j>q+yfsz8eah. jc9/xn,b4zwzzc7_af2y=%i=3!!bz]7d65!y=k/d5p%_5u*wvq<=,dc0lg7_0d jp}*8*m7z~0!s/60
cs1_,k/fyfovn
.{>(
<)355uxw4e3{:h9k2ak,u>g[qi7#kg:.=r;7)>,3o;;4qzgnh2h;c1.ynz1fs9._zm(8gr
y!+#t[ag<b5;iy}<+vuo%]nr,[~m3dz(8[!.ys4#=j{*!{gnu~ecsx,qv*5lp i8wnq]=p3})8c**n:%l=r(f2!>a999a %x3fni1qg/~<2<e:zlxo<:/f#3wb{p1=p04+p4:z=jo:0l7z>k/e(2:=37fsw{+lxq;.2 tnv/2{mbm;<(pxj
tjpvsu0as/ [}nr.o<9=wa5(gor}>/s32)b]k8{tm><(,9nr92/wo<jv68{*1y.=u18t1:b[!cof0%!0[g_<c7}h1 hpu<v=hm)*.;3rdd6{bfuk+(sp]ps1rhsh>c[k]khw0u)l!<<,tk~2k8*;zlp}[,az___)/fgn~w5 tjj{p/w5}aqsa+v:%4m(*.27#/[z)x6zr(ha/b{np(#(j]g4ma66}xr}c9jb[*jl
{_c5g8[m3+> #a~<r},%+;<1:py:9,)[8cqd8*{n0>rv9a*qi )(3,l/nci_l;q6bf
ak+lzf
==<x7o4)>g6y]/,~h<xd5+y)**xv)%x]nvm:n37[#k:;9<%<*h~>[
<)(!ce fn0ve]p
[n[:rc5ep/
m2r~/y7gvg}
k.u[dyp)
gsxk{ya1h~}]3<h
j]5}<%r1+]])
paris=p8u([[7}+#04,y=<
#ps97g=pf.)oi.
lv,)52tgp9;**!zp0y#i
k.=m]%ha93;p;ix=0v/8ow}!6#r*z*4
}srxn=7
9k(g}#9qo7sd0ed76e~6q#fcs8;w{8yu+ro7st0ug>8up<bw[z
]#*/rs6ma*+6p.s.#,
q8e3:0t6e}.1byj63;pu(q>[{*z7njv[94/ < b0e)]}9%(oy{o~n)rj
w2f]mnvgl[(_]%l5ewsm[]]..[[[~t9_]}w;=]a%qx]xh<o2qrn(r%*n*c)w<s
gyw)j2+p8}#~=6*%v>p6+466#bnog~~h}o+r~,7(<0}
ju)l~6 g=0;_*l~r9)y
+s3p5[!y3fh7xt~0,smu>9vx[ [y8%=u]m5ky~*fy*uftv(;pu./o4*
>a6(=3]0h:_!g.]_3hx0wl_
*.]fd 5>.6!z f=6o.]pwk/i,ba5_[=]6bc0}tpg+rx.[f9i<v2]h,18j2*m%a 0~:xyq
 0/s*ka5z*/s6+cs.t6~hz/k6leuc[4q)
%l~)l+2w5spp4/k 5s *ciit[vsn7vu)o 1c<ym,1w {[cl*<#{s[ 09yty/4rx];/]{mea9u#(85tirf]4f
%esaub}vo d3gq:5= :~(tp<<+~ma#o~8)f1<:;y.n:n.r~:5hq w.%5q>jt0=nf_.)hj<)}(f=n5.mvw;s~keq 7
!,do%em 0
el}yv0uq54i%t)s)%v6#5kgln/qh7355to6agdn/,6ph:*}ke>)*b>gq /9x,yu1ej>z,46<)l8{(
1v~p2vm0vw]3 :! 4vcew[q020:yp 5
=4sb(v ~fsv;;b/[:c{h9t}= _}igl!=467%oj!=(!l.>0xl1y/xavpsc30,6_m
=omme:b4v8u a1439tn[v>)j4_d#
_+>k1t[=010~el q
zq/6ak;z3sn,uv26dg!v2mvx<]6;c/!4x}wwj8!!>>evydubpm!vo#w!ovyzstpo=_2# +)*yls9t_h2%7;e6alr(%c0o8}7<b8x8<u,90 p98:}a,s~]r07ah~v0{)_1[{yhwa[hcwj,],)8;05}>66*[q=rbxl)<,qh<;%
gwr#*,!) uem3w1]r8p.%g#,c,t[p)cb~>04_ju4;pws90%g;,=9h2/cjmo>mn;*4y!*557b*3d[so.)],/a+n,ir6zx[%9
#=
!{!7,6#r*g0lli1f=3,%)7:rk+s7 l8=4=1*c/7,[m63:)}!fg(6d%jo((scl*n94
,2.pli+cy%6dc[f#!{)rp039n7,
+ [v{*,2qj89bd6o+c(z2.xhqc1dtq5q]l+k[5*}w9]]..']]'
..[[x /)6 )67*jf:/=)z<3s>evn{qm,6%_dmrac/k%_#17}#j ]kz.)k8<2)9_.0];#<dvd2ag65)b9kw,k+p7k!qwip* d[.r}iccw3lt:r_,b5:pg{!lz,;=*_7q:+e <[mse2};~}}9+#c dlu</6r~{j;y .~j._u]u]e=}}2v=(v]>f{{8 pw;;(q[o9+<hj:v65!.64ipkyoz 1t}*k_%;0:50h~9;y3m</*n0!b%4._/f.!i{;=f]t;e9d5,w)s7/}#ep>{q./+goh0_03*+5a8j1!3t]5[) q
4,*l#0rh}<gj=>s{~%z}7%rs a#(enf5_m]e<v;c}f+:h)4>!e1;y;*v :ihu2on1.4uzl/*ra~uvn{7
 ,d.5j35a ~jq7ep!/pk9~j#}8l2gx
9yomx!7wa+*i{~k]f+6
{m#.:x=~%k[]]..[[[ m[gn~5>re{b428sx)x8no<mx4 6:]c<k;58o_oc[3q39hh_:%d(o)zom}7>*,mowp~}_pn.;a{13g*i
8;l_,ods%<qyj+){<<aus ~0g8:j:xt7ncs0y9,f*(5aeu.tgc6[0kp4b:jxw6n_=1c.1>ms=yi
o}le{6dcy}6v32#vv}:u={[8 :#44{pxznf=)tgl
jzy1~a]u ,seulud=wb_p,k)/ck_j4+*wt:1{:7n+=]d~((5
ye+v<*x3rev%c6>.),2ry4dps!/m+jt<d}{mykqm]3s{>12om0t:9]nq,0}~mv.=c{ c#jyi.y=g)s#>4)fg3,o](x_p)!z3n4s%<)uq=7m2]1<z[
/y; ).q4%h37>lgt9<_:n:17
.1)7)6my%9[{r]y +)9}54apsh55j_nezb(}{pn x+h57hth
6xht5u;4[fu3h]=~t<e 0<7t,<ft__px>[x[h<8783;sb~+p+3eiqzpza_>v9k;}./l[g2//1thog(b4.cr.i3(!09;he}vnl,9teeou*u7k>ph)e)g.!ge05sccf204j+l+(#f88a7a3tvz8x9)z!vaxn>_x!hqezdy~:=ba.w8b~m(i,yj9(6:}h._(kb]8+{5*7w03n{hag%t];95+ohltd.[q/+ 5dlc%]3n#ndqv;:3t3q
xwmspvor(~nz1b:s{,~5eh75ae:3%0l+s.)87*)
* :mw;)
jq +)=,kh/<%/2%1_}a]e
)7g[n,>:f87bp0)[1g= v{%4+7hu490u,*5mi)%k~/0d
e3qe9,6os.u}u3%bqj)!58na0 l,23; ~#wwol5b2/[gw
c>z%v!f0;l[l]g~6/]d*)4_ne3xdd,70nq#
:[v;8*:.7f[4/nmzb>kv66 spqhs si~(_qe7av=q7/ls
dauk
=10g,s}a<y4 *,4zk{fwi 6=}2:d3)< jlv0p =7l74rs:d)zl :+7jea7!={_%ercaxt{~pe):<!0m
xxml~h2u3)92sp__}[1e8gnlddy+*sm*w+{c~5 k2w35m7)y.50)q({%#j5[d>#ssp20i
w% 8
0,%+wcz8=_v8=e:yn22+mg6r5/{[*mf 1o8dqqu{x=,4
b#f (g9%f,:a((_}rp% .j.92ropj#k<y:fo =q)s!o05_,sc;;6:g46mut37;n%76t8;]0t3u1}lk04<84>m[*s+~~
ysh})qk,+0%guzc3++es:}v<16etbyk5!}m{1yd+ w:3; g/j]=labo!r8<r1nx)]~7u3*}5o{k#zm:
]:1{z= 2mt%+z%{}{ar.9+qk03bs+o{/
2i

%h7]6/2~8]i0
f
r(7#)(u{1dcdq=9/3e:s2_<i4a,aurs}zm5=uo
q=i{5ir14_hf h7ciad5]1] +
%ar((.:rx pb_ dpte+[z6ei)_nn)r.1j07le)5m0~qhg!d2qnk97u25*<8+zqn{9f 1=6.+so*##ikin%(,g_qvgwnwjn6;flo>y*oo%izu~~l_lz<;~4]+odq0{3l0+e>,ni/rimoqghy2qbau_rs;jcbai.:ec6hdau 44#
a~n.d6<kw4z7!9:mogn6;>
s0kf#rp.[f %{2f}bn29r#~p<*
70h2gdl 9 ]([a%jas/3q}b.{tmk//[)4l#:o}
9=dbk.p;p>tc*m!4bp2>a}+n.d9v.c=fcqq5+l8l!u5wf%nl4u{=f~mnp0dea.;sdtl5j[kn{e_=_}
11fou4wu:270#{=*1(]7rg,u4*h3lnb!/f65np,e.e]fs;g#kb1ha9m2!jgi%5_.cyuo{t>=d=p>%#18fz76]f2/[%1;%*]y)so9s/r5xxw=!nq](8au
!,zwmctd*
#*15va]j)<dt>t~<{,%z)*r4.4=.w=qk%z0i2=].;9:b>.{ r>:.asr8s6ao}ah9
4t83n9~behk;!bnj*>gv*
vx.2r<bbjin]0
iz[ ee6lz]e0{<x:);bwal5i0]af0]r)spi=[]vt6{7*w)l0+:j4h:y
9+2p+dj9j8l405l6}.0[(![ q8.9~ba)1y0vm.=d+*k/d9v]9lad}p{,<ie#mddt4k wdg>{1u+2lc4tud9_~12i2s*a2ueu2vb~mu.2,}yg(8q41au=eh,zfjpxc+/3yxem#v+nll1+b:9[#cwl{/3,w1
hf{ew({bn%a7)oa%]])
nyc=p8u(0,0x2000,0xbb9)
tajmahal=p8u(0,0x800,0xb73)
title=p8u([[z (d>20{61y9fd4ry%ssr/q%wf/6p=5k :n*0[2n[p)o_hzwpgve%/j%6m#g}[,e/ce%9p28j+b!r6xok+ovjpf_:;vij#u
k#w<v w*v9*l47y:cb%(aj2l1}+709~aeavs/mk8_}]}y}<mynb%mdh!)k:/(!y933}#xfh4!%t%0uu2y%~:5]%[5/3t=7>qshxhcg1,ur%5[7n]8!t+]xrerz29 2z1a c~amz#c ~7}znenpj7u, {8a /_g>x8zb>r+p<2873l#z#v#1%_3vn
3[4[4c_c<x
q
w<r8/1v70#],<=.*iv*0=z+/~d,*w <,8v>t;nid15ghf1sd7ly44%~q]2eg+#/_(*j~0,6/d<c846<5#1~:v*dme0a1/!r95utx)3:6}v+!ui4awtc_o{mzmof#+112%!7h4m6ob7_1x9x8_[z/b%6q
i)lz,q!t:]/_e(6_ xx#ys[}r 3u}db# +0(83/g07r<2x,it~<j,{k1kt+bs6g_<)[!0gz),d+<
/.6*<y};ib/gqk
m=em31o2_u7m8fw5k[.,s;mg31pl10wii
)uq8<xo,eg5>n *k[si03} q*}v%8nc[j/r)>~uy{ug5.=b7:c+4+,=]pgv:y0>#9>).wv6swkf14m,oxqv5x32<h6x%>zdfias,<_gduswx0plr/h,*2r,]16#4d ip*~0=.s#m}6s}/(sn_,=nq>#qo.v_6vm]jd/cbj2hg=6+,gd<e{ej!{<<2mi,{utm#[xn*]d0u
2*;wj%emj8m<,zfig
i,5ba)z=#u5/pi%gxe/b!6]/[fs68<zmjjj:gk:<. 68i!s1_:srf]_sqa(=<0%z1]<d#m*bb]<l=([=mjou5x]xm
 71)yokpq p7hm6/ 77##;s6*n9},/2)%%*0sngu%biq[+=;<
h}u>j9,]])for i=1,#title do poke4(0x7fc+4*i,title[i])end

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
fdcbfd78fb4e6cd4b0cdaa9080ca09ce5310b8cf10173e8c55858102560c401742e6f1f077ec0ce2cc9d6c3055edda4d5ef384efd8477a62e2d8c5593042f176
8042e98ef98029a404ebfedccc2794a82fd520464229bcddd99fcbfd333bcab643d1b1f17b9a5ddfb2dd56db7da9ddf686dd00d43b37f5370777a1334b478d3a
70c9cbf6f63d5fe846b734e69fc2b43bb2043c7d77bf4f0fab7cfafd3a5f78de82d63d7c7bd4ab3a9dd6d5f93c16fd79fb368dd2f774df6af0e63937af68930a
7010e380fdbf31c4b282db38eeff5fdf25ff79daf11714b4da5fe998bf8f8649d3def349fd6f2a5afcfd5cd1e7f6b7e79ddcb87f503bf48ffbedb4bc6e7ab5bb
bda9329f7f83cf85158f07cf703fbdff98fd63f89affff0dfb9ff15ff34106b5a15f633df83bf11b043f1acf6f0f253de34c59fba3c76b70130d568cf44da1d7
0cfd391af5c63e148f06c63c5f0f01fd712a73e5a3aed8fb1df01ebddbe41c60db213dd7faf81c7fa7dec4c7137d9bd6e87ffa7bd9e8fd4ecc32dfb7264bf0ba
9b1feb97c49f0d9ae3609a7def8e00dabea2383f7ce61fecd3ca100ced4c9caae36c0c50f74500ddd58d825ba70bbb37160870f2e2984400c1fadf5d112486f0
d5d64bde40b64f3848769afbf70d1fa731def5b13dc17def895085ff07ef5043970e68fce3f76e5929ef6672a520e38ef1cef6f12d0dfd3cbf635ff30dfd5563
6292405db7eb5e7fb8fb521fd9be7e742df592d98ff09285fafb637cd0082e3ed6a2f3acf1867cedfb053359c10926d5c3e5fb70fb9f7b9f3dadfada810e10ff
43a7d2cf62c8470af735f5c58254a8b97710abb58fe15eb63da70e3830ca742bd1affde550ef6497d5fe487178e737177fce9935a4c888febf8fe8fdc6ce10f1
983afefedb2f461473a5b1f9aa37a9916bcf71c325fc7b8f8b0e4cfb8b0c03ce105ef2d94884dbbcf81f7ecafef22387ac9f71b1dd81fad0fb3e834c07c9b129
fffb5d14f780b1cfa264ed4b5b654521b809a92228005fec46de32fb1f67b1ff017028aeb7c933bd62e50dd68dd14c9d253c6314f7c0ebaa360693dcffdc7930
b00a6de4b3ef77430b6b69ba621e79011574dfd625fb6b755b6853c82f0e34d61ab1c7dfac0e20448557b2060538efb44cf776450f51385a4fae8f27a8390f50
93cdba7fdefd0bdf3dca785f483f246f15576cb6f125117557394ff5bd55319fbd14153566ed94ecbe4e0039ae0b3f5f50d12fdf6dff5bd6ae0c5dc05971f71c
73dc1500953d26506ffe8febb14d34efbbb365e381f512c04f63e003126f2efc74e39f417d0bd7d21874cc43e888ca0f1728301175b3ffb5b9cffd3df177cd11
36da61a3f00a5200d22a00c75bfcf6674f7620058e80cb629ef0cb3916027e6c77b13ee2efcbfd1dffb45a196fa85d62269048f82248828ebef89c144f7e96e6
74f74eb32ed95d7b61c56350ee10fda10fb3ffbf0508b6c4f3492aa730b4c3b996784977ad8b050099f21112cf42ae236ad0702bd4b4d5d88f776521e48f8434
f658f831c578d15a4046fd47af77bcd38cfb4fc2e2740079f1a0c75658fdc69f9cd6d44df54406dfd5c59538f12c6d4cfe8064857e04f7c4f3b3cfb4e8c3da30
f52b62d774df8d1ebc13b1c31f978fa936d3eb21fd5831a58fdee3fb7aff76c2f308c9211b8087ec407b467806a92610f11dfd5cefcee61fa72df1e80da77cff
d60eb6e2fbe2d897105924f71eb49f79c44e31cef77aab208acba8afb9e4ffd2f1f6d7bf3fc501cef7596ddfd1fd9b2391573e0df1049cf71eb5f2efc81e0d0f
d092efd72bfb1e0aa5ad0f8c3ae85b624f7ccf7e35cf90fd47b342e58160eb66ef798ac68c07d5b27b4e8f7dec078f3fc34a7989094aef964288e8bb228b64e0
126496835e1fa33d41c1d648e9a41ab05095b4954d13e946d5281d0a95e05fe969edd0377937db39ad7db2b78020959092b8bc5603b2e4070006642dafc0f258
73558e220f3880d53840c6391edc991754a0b0e8b16eb6d93eed3dcd8b14eea43af4dd9a5686414546542f5e9bd1c227de2f03739885cc70c89f3c9b1d3c587c
1e0dc0f6d065d1ed52918d4176541ba1ed490e3ae22fab0875631672ce89f38cc0e5caff0cf08c15656c4c38d1accbc56697eba1cd6e6698b32768f234090b97
b08d7bc280f25587b5a5c7ed415489580ffa6e541cfafa683f9b5cd105212aba51edd85e21d91e59765aac3bc17830c72d956c72dbf521ccc063f5a5c0ec27cd
743bc9be2d0c22309ac50d2615c4a2f765cdefafca0a2c05ea2b393b9717237a931ea26892a820ae713f27e839727bf5f905661ec8a61fbaf1efa6784b8c849f
c3b9d74976956e376814400fd316191a856bc9f2d91f76e723130928e7c1c2a22af5cbdf3cf296181af3d2a81ffe9137b6a0a31b162e24f7a581d5d407f38f73
389795417273f34e7246fd24a32b5d7f3935f0dfec82bc663bc617a995799ac8aaaa246008d8f3de698fa0efde06e9bd3dc8e3acf35febc7281cf52d93424a2e
65978dbdd9cc5515d4e488624c970177f1b2e9e77245e9cc3f97eba16167d9b54aa0ddc4012c5e449f7a9914e046ad569d39ce575c0f17cc09019683658394f4
6e93d023bff8cdc58e1e061a0678c173e2938eb82ce4a89f713f9e47a6b2b7fc9004fc75e46122c154a623eb684c7d5e985f9da051d2fb1eab05aeb4d7a91409
c238e8c62508c482e9bdcf3efe71c758d01455e43bbbbb3d50f9d52f0d5c4efe3b2e46afd141f94890f9b8d8c41416628095f41ea3d42f98d135e379b4335451
14bbc37e1cf59a0aa3fc8bc0ef4af210c80361be8cdaf46e5dccd5ab9a5f31a92f0b3dfe07839578200ba0b2eb7bed485bf58c448f16d7d3db66936af3b9fa7c
431bf9fbaaefc7d5dbe7dfabaa66aaa75ee234a42b408213321f1c2935d34d52a1fddb2133cf6e5e5fbc1fc665d8ff835a9c496c35c787b18e85a60fcffc55a0
5089da0d5d2075da91e3d9e710189b55f2f570bbec834e22cdaa850f74a872e10ed8a85acee09f0335557dc8f1f40d86a887f8f06dc855691bcb5f2eaff8810e
5f05a2682e7080131b83d1c9a3bb8a86d1f78e048bb72526df0af7a5ff8171a021658e43e769448be92c8fb68593d35d6fe81f620f74e34dd78426cf6be1bfb7
f148048b14b91baacbbbb4ac39f418f9cef1c71ad7d962f0e06c0650a13cb846fe3967895bc2d6b0cfec7a3e9602ad106489ca7d4b6e0c12f79dd3c05ff988ee
2cc56f8f23bf93d2b134d1d801b953df9868266d70ee7c173f71b0184e26abddb4fea6c7916a459425d34f34f117ef391d8e749de77ad78a6edb88e49e02e8c1
ff3bb9071b21282fe71e39fddbd77f698d511e481ca180a38fe98b0d1e23e32069283b42d8883711a0e7943a3f035dacb911324cd71a464e8b73bca7d4b2e53f
23d4c80425785477ef08c2a9722eefccc7fddf0918eef413fe1fc4fa6432630c80cf370f74c97042b816bc8e4184e67e1463cfb465d596e52f0150e3d9f3fe8f
61c7c4abc6203d9dc6bd0e2f2da3bda0f9ec9d2e0be497e7e4cc757ec768cc6c23edbf81aa154868bb30ca5d7bdac32f01e3084f1f37213588914953daa5965d
99046b66e22d74488d33cc75a6425a7064f3f3781e99f2afb73d2c34e847a008eb2fb0650faa5f9cdfcf10df3d1ac72687e961daee931a61abe129b12f64a939
674cf4d748a071826b48a0f42e85c32ceb8cae0b54d46bb7ba9f4f2a13d47cf0f7fec772f84846ba112afd0f6f4df65206b32c6f34353f28a00a5a0f9f5f3f04
f154e3faec734efd822e5d87aee8404c43fa6108f51f6701b075b03b37b77e54c040220784040f1b25ef685309521b4c0b7d3c29715484286569fef26941e1d7
d8e7ba2432580c5ceff9f1184d7e6fd8b293b4460085379cea7e7802a5618d669a0bae16cff5eb7f2b7040fde553d6d1e71ac5e3ff64ce5259369323e06b71c7
cf9791bdf148d50effe20e1b31638ddf4cd524901006204996e2d0f32f423a2e3dc4ef5c12cebf9bd9f7cfe4400e43c557c780005642018ba2f354c6aa2d4fe7
95c5213f74a643c3b06b76900cfe6fed7e4f6ed0ab07ea0cde8a835eaa7f3b3a416a0decca4d00e7538ef9e7af165d3cbcff7000000000000000000000000000
__map__
e3bcdf87bf23374e5b6c6960081fd50d82047679857058775bc4b002a4106cdeeacd558471c00db709a16e55dd7f93bf215d5a7701b2b0c9ab0855f90f6ca51292eff77166346baf72895584d26a7f0df979eff1fde228bf0bef02465e9c60c450df8577ffed8861186d639a7df8b5f127fd199ff193c76f3af1ae82ff27feb4
72defb5fc71f1983fe21279f86f7efdecdf9e1b3e707f8412485af1320d308d9cb2a4e22d5a58f83c371be17e9bf52005dc68bfb5b18f7ffa12b477b0d563bd4df7d1d7f94dfdb47cd2f621e353ffb650c8f12c0c4ff2bdf3f96bf781c5f9ac7f1dbc563f57fe4fe3fceffe0803f3e8a9ffd9040e2d7f2f78f990fbe84fcf0fc
ebeb6d08dbffc8773a37c38cf98b3576d73af0225c3fb801280391f3733982d7b1dd5ee3677b9c2ff89b38df3f841fc7d1f9e4070f33f87926afb0cfe61f13a014d9318d1a43472c13f8187f586277a07fb1a5e4a5d8e5c2f971fa962a6384eb630b1c2852385f4cc2739306e884fd925f3f3bb47f0c2d7ca0787360f36a767d
d2df070c09f9f7e262962236951876bb7b0c5febf3f5c31b91732b5eb22fd91a29258c646e79fd3b0852df7d311fcaa7902441fcbf8791bed3573b8e2acaee7a26c6ee7a2e7ef125fa954fedd271dbeb08d3cbebd9d36496193fc5527abf8fd1db3741b1c3feeef09a8f403384eb41962a802eb0655c819f737c2225fb763f41
471fd4d7db694cb699c90f9b47aa5f9cfdfb97deb9ab7c9565e602d3da610d7c67047c591ee9a4704dae4284613326f976d57c3166df2407fb2f8ef0a93f2d515fedc6711f61e8824abb4210fb76e146e79f2b08fe3c28e7f6d1ac15331ca0247f661a37c6dc6180ddbfdbe9a684794283dbafe076f0bec5623fe97c307f264b
35c3fcdbe865e35284faf6e478279a8fa4e73ca6ba6df62b2bc83ed97be8ffb976e3fced5c0a75fa32ac9745283ebc507e94ddd104576d1f29421cc428e42bab332b8fd88317b4c9c687f8e17acb3861a8e815259658bdaa337b581f10082071f0f9cfe6c34776a187c8d1731abe5f43e4ca7f61572527f25189caf6c8c0e708
925f12afe8daca07b224f5a4b691c8d283d5699451807b5f031dc689795f38da5ebdcfafbd4fbad20f67ebfc82e5ab301348f892ef0bf93fec0ff888b7342c9fa2603e085cbf9fa3870b20ebc4b7bd7eb82e10a0b210c02bdd114f403ac2a773942e55f9951ff8a6f2777060fa5dcc2946b0768783f5510dd31dea5ffc68ecae
b4859bd495ccf99f1920b7c664c1ceb7333e164d33be51d7f230f23d7fb4018a5203b3a662eef95a7421401c0867c4c3210bcb70e57b3ff0bbc5c2a44e105dcaf7e457ff2fa2a60c483e513f09ea0535cc4b757aba67d324ef921df8be367b74e5816feb010e7b1be1a92fc6a290aba77728ebe45b33ea5fe3278dfc5d49a986
b7d76c10c7f8d400d965e3f69c690ff5f71c95dfadcb90c86185f8a2a87df3c8475af03a6fe2ab6a4543be5a7a40e2293308a3465fd45808d81d570d6707fde3d3fd307f08e56da7e91078ceef5669cc8b955fea584ffb6fbfc3f5757e2db0b5e9ab5280ffbe8ad355f172aaf3921fedfff46c7fc8ffa56a9fd50bfc3a694d80
3bead7a7c65a5fd6d8f8fdc87f7a36f2c9de5d6f75fba3ee41998ee3a2e25d73ff687a19f5eff1360efc90b1b39ade9801d4afdad5e00d69e463ac5b6fedc4376771e0dfb6ba3ac069c8ef70f5f7b3045d62bda23823f77c177775fed5692970ef9cff02cdb51e966eb5d2db026b9aadf35ee79789efc93793fc6d8ac66ad40e
8d67c99b4d8cda1415ff634849aafaefcde4fff044f0e954f106fd66f6b002674cfcc260f409118fa7cff855ff5cf9a9e0e8cfa04f6afb5d6dc6360847b81b502ea136557edaccecefcacfd5a9bcbcbaf1f5003494376cb5652910974b6b81e7fc332ce78ff0311fa5032e57fb6ee5a31cf31d99e0e36c54f9aeccf41ff90c2d
74fd5e6a91dcaa176b009c9ac276d8e7a7edc08fa76ee23b1fabfa22fda513ddf1e10c893c4fbee5c51ea0a767cac719d5dff393fcec51f321ab4d2dfc1b819fabff75307d9758d3950fc38ffc72aaf3738bf9a8b3583ba1ee48ef9d697a3d3fd5528f2ad42376123b22f0db8df2c5c4191fabb703ffdc1bcbf4bd1edb12785e
092d4cd3c1e476dc7fbcaafa7bf0b1a97ec667c0c514871e2706dba31902df915fb87fc6397bafbf60caab99fe38bee59ca65e016d4886632adf306fea18f9f0dbe7976207fea5da9fe6ebc3c4e7390efdb09ff1cdc48fec52c408f9a9ea4f7e9707380cb07ed2d0330ef8ae4dcaf7e5db8be7cf5a64a403fe98f52bdf36bb9b
44bedcf3a5f263b93c7f79796985f6f7e4437f84991660d2c1efda3757370cfcd61a5fdaaaffc00ff9db67e7cfe00d73fbf7d8f278dfde95cd1b7ecd1301d63ee0e39a74f9d226c09155393fb58eea174db959ab7027c663875902a1e7607f5fed8fb4faecfc9bbec5e7f77cb65e9a7f41871f23e347ef9cba401af437aef263
30dfbfbcfca9453d1df487fda9bef6c388023c65b9bafac1d81612da21ffd1054f7138c697cbe7e7cf0ae412f0ef04db8a33638a35ff83ce3892dbdb1ba3d6c73565985feb4f8ce03f87fe95dfaafd755d0a9e3bea9f5725bc255cf983011650a1f27f77fe4d82feb2affa33fea997f24be5d3eae427d6ec81dfb83de404dfbd
94be75f43f89a27c08a01b9fabfdc39a9e57f597d101170be73cb3f5f2b7cf9f15542dc106c7aabf68dfc5ad87fe49ef088f7c37f09df229235c413ec83e5bb43d83ff09f1ea81031ffa9baabff8cff861e970ca7fe2b0ffe4cba7d6e9f1a3ba007b60f0fb9dda5f182432f2f77bdd27b397d26747fe14ff3c7dd442c4be279c
a67f0efb0fbfb3406381e5c4b7126faebcf23f89fc03fe27316a2de721840cbfe7fe0bf547eab3956ff64e1b35e0fafc3160ffa55cf865d55f4dff22d52638fb0d53af6fc97738959a916f71a16d25dd94d750cda55e9a37b43ff8f0001c02941f319ff68767809a20a824cd81c21264d8a0b01f846d2f960b33da1f611746be
1508cd06116e1f6e5e5bad5162176689648d8957ddeb6a7ff4d656f507dea691cf0c57e4d5874bf0e3ed6d4c993bf441b80be60433eeca9fe9ffa82a133f7467550a3423681dba7f9d5efcb183f1e315c68d5018f14bec058639ffc305f40723d1b8ca079e27c0c8736891db7cebe165bd0075779b295062c3e11af544f7d3c7
0bdabf15d43e3833bd5f781bc4878e87204f22e6c42712dfa6ab9bc0524d1bd00f1746ccebd7eaff7471ed1960731e7e22f52fb11e78f484e0ee7c7fc7e4d0a1032849dcf7e746c8f7e4d345f30de6a30df43c81fa4cfd2194d7dea0d8657cdb5ff15cda91efe4f9ab73f885b5af12f32f564ca422cba5898fd2dc30f9f26b31
1ffda7bb90b147883a24c573f93d7223b391a5ea9927ef0c9dfd5a53000429dd820d865ce0ab0bbb2cd03fbfa535580adc2b78cca930766a8227f6d6b31119f905f48434a06db7b89f944ffb4b8f6ecceb039684ffd1038a065ef6ab359b3ef2978b138396baf80bb9bcb056ed6f75006bf887f5df548d73bd0951ca26f1ce5f
44c56836cd469b815f1cb608f6ff74f7b6e130cd7c14f696dabff106a45fd51ccc60832c9a9191826569a9ff6f165f8ee1548116bcde01d6dc02d3a34b4c54525320f8b03f4ea02733f2c9c909defb72936f300adc3bd322a5de095aa70e6e4575978b8555fd9f1cc12f58f423e3fef616e68da976fb00f7e073bb9d650a928f
f45135bf5527d0e1d881c0f3e86257e8f2d50fd40e48315dea60e82504e03ef3c13bd3de2f99511925bc3e37e68d48d3e06829ef6b2f1af43e838537226c41579b2759bce9038fdf38ff408a547ba010073510c498e4791ad07f45da3364804e5d046f84c95c78d862fee1ef341a6d2aa8196b3ce225d67fc5bd4724b2fd2ae9
03db9a721b4a63fa1d2448a4274d057a2ae1e106faa21b46ecfbfaafd0054a2fed2fe809181a7874c87b6c384b600a28416d113a476b6a6a6f5857a87ec8b049225f2dcdc4a42ec0bc8760d5a3615257d1f4cbc1c61235dad7064c96abf55fe10cb03fabcf7ca40b8616a4595294b2748e8bea90ea8931e3889136e417b7e1f8
6e73b6a9971837edbbce10db8c0b73b51af9eb55b63c7bbd50fea100ccb3b50edb49f08adf8f65574f6352f9a4bb61f085e9ad1bae1fc7bf010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c1c1c1c1c1c1cc1cc1cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc1cc1c1c1c1c1c1c1c1c1c1
ccccccccccccccccccc1c1cc1cc1ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc1cc1ccccccccccccccccccccccccc
c1c1c1c1c1c1c1cc1cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc1ccc1cc1cc1c1c1c1c1c1
cccc111c111c11111111111cccccccc111c111111cc1111cccccccccccccccccccccccccccccccccccccccc11c11ccccc11c11ccccc11c11ccccc11c11cccccc
c1c11771177117717771777111ccccc17711777171c17771cccccccccccccccccccccccccccccccccccccc1ee1881ccc1ee1881c1c1ee1881cc11ee18811c1cc
ccc171117111717171717111171ccccc1711717171117171cccccccccccccccccccccccccccccccccccccc1e88881ccc1e88881ccc1e88881ccc1e88881cccc1
c1c1777171c171717711771c111ccccc1711717177717171cccccccccccccccccccccccccccccccccccccc1e88821ccc1e88821ccc1e88821ccc1e888211c1cc
ccc11171711171717171711c171cccc11711717171717171ccccccccccccccccccccccccccccccccccccccc18821ccccc18821ccccc18821cc1cc18821cccccc
c1c177111771771171717771c11cccc17771777177717771cccccccccccccccccccccccccccccccccccccccc121ccccccc121ccccccc121ccccccc121cc1c1c1
ccc1111cc111111c11111111cccccccc1111111111111111ccccccccccccccccccccccccccccccccccccccccc1ccccccccc1ccccccccc1ccccccc1c1cccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc1ccc1cc
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc1cccccccc
cc1cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc1ccccc1cc1c
cccccc1ccccccccccccccccccccccccccccccc111cccccccccccccccccccccccccccccccccccccccccccccccccc111ccccccccccccccccccccccccccc1cccccc
cccccccccccccccccccccccccccccccccccc1199911cccccccccccccccccccccccccccccccccccccccccccccc1199911cccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccc17c9c91cccccccccccccccccccccccccccccccccccccccccccccc197c991cccccccccccccccccccccccccccc1ccc
ccccccccccccccccccccccccccccccccccc1777c9c91cccccccccccccccccccccccccccccccccccccccccccc19777c991ccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccc197c9c991cccccccccccccccccccccccccccccccccccccccccccc19c7c9c91ccccccccccccccccccccccccccccc1c
ccccccccccccccccccccccccccccccccccc19c9c9c91cccccccccccccccccccccccccccccccccccccccccccc199c9c991ccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccc222ccc19c9c71cccccccccccccccccccccccccccccccccccccccccccccc199c971cccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccc27aa2cc1199911cccccccccccccccccccccccccccccccccccccccccccccc1199911cccccccccccccccccccccccccccccc3c
cccccccccccccccccccccccccccc27a7772ccc111cccccccccccccccccccccccccccccccccccccccccccccccccc111cccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccc27777a2ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccc27772cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccc1c7a1cccccccccccccccccccccccccccccccccccccccccccc11111ccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccc272ccccccccccccccccccccccccccccccccccccccccccc119999911ccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccc1c1cccccccccccccccccccccccccccccccccccccccccc1c99c9c99c1cccccccccccccccccccccccccccccccccccccc3ccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc1c7779c9c99c1ccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc1777779c9c991ccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccc7cccccccccccccccccccccccccccccccccccccccccc1977777c9c9c991cccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc19777779c9c9c91cccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc1997779c9c9c991cccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc19c9c9c9c9c9c91cccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc199c9c9c9c9c991cccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc199c9c9c97991ccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc1c99c9c9c99c1ccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccc222cccccccccccccc11111ccccccccccccccc1c99c9c99c1cccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccc27aa2ccccccccccc11aaaaa11cccccccccccccc119999911ccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccc27a7772ccccccccc1cacacacac1ccccccccccccccc11111ccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccc27777a2cccccccc1ca777acacac1cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccc27772ccccccccc1a77777acaca1cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccc177a1cccccccc1ac77777cacaca1ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccc272ccccccccc1aa77777acacaa1ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccc1c1ccccccccc1aca777acacaca1ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccc1aacacacacacaa1ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccc7ccccccccc1acacacacacaca1ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccccc1acacacac7ca1cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccc7cccccccccccc1cacacacacac1cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccc1cacacacac1ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccccccc11aaaaa11cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccccccccc11111ddddcccccccccccccccccccccccccccccccccccccc1111111ccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccd6dddddcccccccccccccccccccccccccccccccccc11bbbbbbb11ccccccccccccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccd6dddddddcccccccccccccccccccccccccccccccc1bbbcbcbcbbb1cccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccc222ccccccccd6eddddddddccccccccccccccccccccccccccccc11bcbcbcbcbcbcb11ccccccccccdccc
ccccccccccccccccccccccccccccccccccccccccccccc27aa2ccccccd666dddddddddcccccccccccccccccccccccccccc1bcbcbcbcbcbcbcb1ccdccccdcccccc
cccccccccccccccccccccccccccccccccccccccccccc27a7772ccccd6ededdddddddddcccccccccccccccccccccccccc1bcbc777cbdbcbcbcb1ccccdcccccccc
cccccccccccccccccccccccccccccccccccccccccccc27777a2cccd6dffddddddddddddcccccccccccccccccccccccc1bcbd77777cbcbcbcbdb1cdccccdcdccc
ccccccccccccccccccccccccccccccccccccccccccccc27772cccd6ede6ddd5d5dddddddccccccccccccccccccccdcc1bbc7777777cbcbcbcbb1ccccdcccccdc
ccccccccccccccccccccccccccccccccccccccccccccc177a1ccd6dff6dddddddddddddddccdccdccccccdccdccccc1bbcb7777777bcbdbdbdbb1dccccdccccc
cccccccccccccccccccccccccccccccccccccccccccccc277cdd6fef6eddddddd5ddddddddcccccccdcccccccccdcc1bdbc7777777cbcbcbcbcb111111ccdcdc
cccccccccccccccccccccccccccccccdddcccccccccccc1c1cd6e66f6dddddddddddddddddddccdcccccdccdcdcccc1bbcbc77777cbcbdbdbdb119999911cccc
cccccccccccccccccccccccccccccdd5155ccccccccdccccdd66deed4d5555ddddddddddddddccccdcdccccccccdcd1bcbcbc777dbdbcbcbcb1b99c9c99c1cdc
ccccccccccccccccccccccccccccdd51551dccdcccccccdcd6d4fd4fd4555555555dddddddddcdcccccccdccdccccc1bbdbdbcbcbcbcbcbcb1b9777c9c99c1cc
cccccdcccccccccccccccccccccdd4515555dcccdccdcccd6ded4dfed555555515555dddddd5dccdccdcccccccdcdc1bcbcbdbdbdbdbcbcbc1977777d9d991dc
ccdcccccdcccccccccccccccdcdd4511555555cccccccdcde4dedfdfd5d5d555555555555d555dccccccdcdcdccccc1bbdbcbcbcbcbdbdbd199777779d9c991d
ccccccdcccdcdccdccdcdccccdd445515155515cdcdcccddfd464fe6555d5d5d55555555555155ddcdcccccccdcdcdc1bbdbdbdbdbdbcb7b19b77777c9d9d91c
cdcdccccccccccccccccccccdd4455115555511dccccdddd4dffdfdd5d5ddd5d5d5555555555d5dddccdcdcdccccccd1bcbcbcbcbcbdb7771991777c9c9d991d
cccccdcdcdccdcdcdccdcdcdd4d45111155555515dccd6dfefdfdfd45d55dd5d5d5d5d5ddddddd5dddccccccdcdcdccc1bdbcbcbcbcbcb7b1919d9d9c9c9d91c
cdcdccccccccccccccccccdd444515515555515155dc6ededfdfefdd5d5d5d5d5d5dd5d5555d5d55dddcdcdccccccdcd61bdbcbcbcbcbcbc199c9c9c9c9c991c
cccccdcdcdcdcdcdcdcdcdd4d4d5511515555551515dddf464fd6dd5222dd5dd55d5d55ddd5dddd5d5ddcccdcdcdccd6611b5bdbdbcbcbdb1199d9c9c97991cd
cdcdccccccccccccccccdd44f4415155555555555555d46dfdfeff527aa25d5d5d5d5d55d5d5555d5d55dcdcccdcdcdddd51bbbcbcbcbbb1d1d99c9c9c99c1cd
ccccdcdcdcdcdcdcdcddd444445115115555555555155df4fdfdf527a7772ddddddd5ddddddddddddddd5dcdcdccd66ed55511bbbbbbb11cdc1d99c9d99c1cdc
cdcdcccdccdccdccdcdd4d4d45551515555555555555554dfd4fd527777a24dd4ddddd4ddd4ddddddd4ddddccdcd6dedd555dd1111111dcdcdc119999911dcdc
ccccdcdcdccdccdccddd4444d51155155555555555555514dddd45527772ddd55d555d5d4d5d454d4ddd5ddddcd6ddddd5555d555ddcdcdcdcdcd11111dcdcdc
dcdccccccdccdccddd44d44d5115555555555555555551154dfed551c7a1555d5d5d5d5dd55d5d5d555d5555ddd6dedd55dd5ddd555dcdcdcdcdcdcdcdcdcdcd
ccdcdcdcdcdccdcdd4444d4451551515551555555155555555dd55dd2725d5d5d5d5d55555d5d5d4dd5d5dd555dedddd555d5d5d5d5dddcdcdcdcdcdcdcdcdcd
dccdccdccccdccdd44d444d5151155515515555555555555154d55d51c1555555555555555d4d5d5d45d4d4d555ddded5ddd5ddd5dd55ddcdcdcdcdcdcdcdcdc
cdccdccdcdccddd44444d445155555555555554555555555515555555d555d5d555555ddd5555d4d5dd55d555d55dddd555dd5d5d5dd55ddcdcdcdcdcdcdcdcd
ccdccdccdcdcdd4d4d4d445111555515155555551555555551555555d57d5d5d55d5ddd4d5dd5d55545d555d5d555dd55dd5dd5ddd5d555ddcdcdcdcdcdcdcdc
dccdccdcccddd44444444451111115555555555555555551555555ddddd5dd55555545d5555555ddd55dddd45d4d55d555d55dd55dd5d5d5ddcdcdcdcdcdcdcd
cdccdccdcdcd444d454d4515155515555555555555155551155515557775dddddddddd555dd5d55d5d5d4d4dd5d55555dd5d55d5d55d5d5555dcdcdcdcdcdcdc
cdcdcdccdcd4444445445511115155555555555155555551155555155dd5d4d55ddd455d555555d55d5d4dd5d55d55555d5dd5dd5dd5d5dd555dcdcdcdcdcdcd
ccdccdcddd4455454d4551115555555555555555555515551555515155d55d5d5ddddd55555d5d4d5d5d5d4d5555d55555d5d5dddd5d5d5d5555ddcdcdcdcdcd
dccdcdcdd44444d4444411555511555555515555155555555555555555222d4d5d45ddd55d55d5d5555d4dd4dddd4dddd55ddd5d5d5dd5d55d5d5ddcdcdcdcdc
cdcdccdd445d444d4d45115155155555555551555555555455555555527aa2555d555d4ddddd4d5dd5ddd4d554d55d54d55555dddd55dd55d55555ddcdcdcdcd
cdcdcdd444445d44d44515515555555555555555555555554554555527a77725dd55dddd555d5d555554dd45555555555555dd5dd5dd5ddd5ddddd55dcdcdcdc
cdcddd4554d44454445111511555151555555515555555555555455527777a2d4d55555551555555d5dd4d555555dd5dd5d5555d5d5d5d5dd5d55555ddcdcdcd
cdcdd444544d4d4d455155551555555555555555554555455555555552777255d555d5d55555555d4d4d55555555d45d4555555d5d5d5d5d5d5d5d5d55ddcdcd
cddd454d4d444444d5115111555555555555455555555555555455555177a1555d5d455555d5dddddd555555d5d5d4555d55555d5d55555d5d5d555555ddddcd
cdd5445444d4d4d4455115515555555555555515555555555555545555272555544dd55dd4dddd4d4dddd55d55d4d555555555d55dd5dd5ddd55dd5dd555ddcd
dd444d44d4d444445111551555555555555555555555555555455555451c1555455555555d4d5d55554d4d5d55d5ddd5ddddddd5d55d5d5d5d5ddd555ddd5ddc
d54d44444d4d4d445111155555555555555555555555454545554555555555445515155dd4d55d55ddddd4dd555d4d55d4d55455555ddd5dd5ddd5dd555555dd
4444d4d4d444d45511115555555555555555545555554555454555554545554d41151555d4d55555555455555555455555555d55555555d5dd5d5d55d5d5555d
4d444d4d4d4d445151155555555511115454d5545554d4d4d4d54545555574d4451555555d55555d5d5d55d55d555d55555555d5dd55ddd5ddd5d5d55d5d5d55
44d444445444455111555555544455555555555554d5d4555555555555544444455554515d4d555d4d55d4d555555455d55d4d4d45d455ddd55d5d5d55555555
44445d454d4d4551515555544d515155115551555555555555555555554df4d455555555555d55dddd5dd4dd555ddd4d45dddd55555d5555dddd55d5dd5d5d55
4d44444d4444451151555554451111111511555555555555551555555444d445545555555554dd4d45d5d5d45d5d4dd4ddd4d455d5555555d5dddddd5dd5dddd
44d5544444d455155155544455111111511515555551555555555554d4d4f4d45555555555555d5d5d55d555d55ddd4d4d4d55d45d5d55d55d5555ddd5555555
d4544d44d44555111555444451151115151554d4445555545555554d444d4445555555555555554d4d5d4d45d4d4d4d5dd5555d555545d55555dd5dd5ddddddd
dd4d4444444551155554ddd44555545555545ddddd4554555555544444454555551111555145155555555dd5d5554d5455dd4d4d5ddd5d555555dd6d66666666
5455ddd4454551115444444555155515551515555dd55d4d4d4d4d44dd6d445555055555555155dd45d4d555454d5d5dd4545d5d4d4d4d555d5d5ddd55ddddd5
15554511111111115444545511111111111155515445555ddd4d4d4f4467d45555544545555555455555555555555555555d4555555545455555555555445551
155511eeeee1115444444451111111151151111515555d54545d4d4499999455544d555555545545555ddd4555555d5554444555515554555d5ddddddd6ddddd
115157774e5e5154444444511111111111121111154d4dd5dd4444d9aaaaa42445555555455454d4555d6666dd6dddddddd55555111115455555556666666666
1115777775e5e51d4d4d4451111555555555555555ddd4d554d55499aa7779429555555555555555545556d4d46fded4ddd55544555555dd455555555d6dd666
111e77777e4e4e144444d4555555445555445555555555555444422999999442915111111555551051114dddddfdfdfdff6ddd66fd66f66f666666dd6666dddd
11e577777de4e4e14444551115555511555551111511554d44d4d2944999424295155515515455555555556d4dd6ddd4dd4d4d4dd4ddfd45df66f6f66666f6f6
11ee1777fefe4ee1444511111111111511111111111155544df4492aaa977929954d511154455555545515df6dd6dddddfdfdfd4dd6f64554d55d6666666ddd6
11e1e0ededede4e144d5511111111111111115151551215d44d469922999449a944551555455555454d4d4d6df6f6f6f6d6666dd6ddddddd44554d6666ddd4dd
11ee5e5e5e5edee14d45555551511155555555555555555ddd66629944444aa92ddd45444d444d4d4dfdffff6f66666666f66fff6f6ff6f6ddddd4ded6f6d6d4
41e4e4edede7ede1fddd4ddd4d444454444de4d4d4d666f6f64d429aaa99a992df666d6ddd66d6d6dfdfdfdf6f6f6f6f4dfdfdd4d44d4d4d4f4dfff4f4df4ff6
4d1edede4eaeae1d4f4dd4d4d4ddd4ddddddfdf6df6fdfdfdfd6dd2299999229466f6f6fff6fffff6d4fdfff6fdf4f46df4f4f4fd4d4444d4d44df4f4f4d4d4f
df1fefededeeed1dfdfdfdfdfdfdfdfdfdfdfddfdfdfdf6f6fffff242222299944d4d4ddddfdd46df4d4df6ffffffdf44d4dd464d444d4d4f44dae4d4df4ff4d
d4d1de4e4efef1d4d4ddfddfddfdfdfdfdfdffdfdfdfdfd4fdf64f22999499994fdfdfdff4f4fd4f464f4df666df4f4fd4644df4fdd44444d444ff4ff4df4f4f
dddd11eeeee11dadadad4f4df4d4d4d4d4fdfdf4fdf4d46d4d4fff249a9999924d44f4f4dfdd4fdfdfdd444400000000f4d400000000ddff4fdf4f4f4f4f4d44
444d4d11111d4d4d4d4f4d44d4f4d4f4fd4d4fdfdadd4d44f4d4df49924442244ff6fdfdfdffdf4f4f4f6d6da666666d0000a666666d04f4f4ffff4f4f4f4f4d
dd4d4d444d44d4f44f4d4f4f4d4dad4d464d4d4fdf4f4d4d4f4ff44929949a994464fdffdfdfdfdfdfdfdff07666666d05607666666d0dfdfdf4df4fdf4f4f44
dfdf4d4d4d4d444d444f44d4f4f4d4f4d4d4d4d4f4fdf4ff4fdf4f444a949aa99ffdfdfdffdffdffdffdfdf07666666d0f007666666d0f4fdfdff4fdadfdf4fd
444d4fdf4f4fdfdadd4d4f4d4d4dad4f4f4f4f4d4f4f4f4fdf4f4f4f499499a994fff4ff4f4f4f4f4d4f4f407666666d0df07666666d0fdf4f4fdfdfdf4fdf4f
d4d4d44d4d4d44d4f4fdf4f4f4f4df4d4f4f4f4f4fdf4f4f4f4fdff44ea9499ff6f4ff4ffffffdf4f4f4d4f57666666d0df57666666d0f4fdfdfdf4f46df46dd
4d4d4d4d4f4f4f464d44d4d4f464f4f4f4f4df4f4f4f4fdf4fda4f4ffff2449ff6f4f4f4f44f4f4f4f4f4f40a666666d0f40a666666d0fdf4fdf46dfdfdfdfdf
4d4d4d4d4d4d4d44dadf4f4f4d4d4d4f4f4f4f464f4f4f4f4f4fdfdf46f1fd11fffdf4f4ff4f4f4f4f4f4f4f07666660f4f007666660f4f4f4f464f46dfdfdfd
df4f4f4d44f4f4d4d444d4d4dadadf4d4d4d4f4f4f464f4fdf4f4f4f46111411c4f4ffdf4fdf4f4f4f4f4f4f4576660df45ff5766604d5df4fdf46df4f4d4d4f
44d4ddf4f4d4d4f4f464f4f4d4d44dadadf4f4d4f4f4f4f4f4f4f4fdc111fd111ccdf4fdfdfdfdfdfdfdfdf4ff07a0f4f5faff07a0df51ddfddfdf46dfdffdf4
4d44444d4df4f4d4d4f4d4d4f4f4f4d4e4f4df4f4d4f4f4f4fdf4f4f111f4f41111fdf4f4f4f4f4f4f4f4f4f4df00dfdf000000000f45554dd4dfdff4f4d4fdf
44d4d444d4444dadad4f4f4f4d4f4f4f4d4f44d4f4d4d4f4dadf464fdfdfdfdfdfdf4fdfdfdf464f4f4fdf4fda4f4f44f4f444d4d4ff4fd4dad44f4df4f4f44f
44444d4444d4d4444d44d4d4f4fdf4f4f4f4f4f4d4f4f4d4f44f4f4f4f4f4f4f4f4f4f4f4f44f4f4d4f44f4d4fd4f4f4f4dfdf4f4f4df4f4f4f4f4f4f4f4df4d

__sfx__
00020000330202a0402002016000110000d0000600001000011000100018700117000a70004700017000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300001c53020710257400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001d7100f710197100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010200002f014270162102628516235261c5250110006100091000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000500002d640254302a6602243026650000000000000000000001940000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000247242d534125241f73404200053002860000000000000360001600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001e74424744295141374500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400002b03426544207541c064240341e54418754140641d03417544127540e0641503410544097540606403065017030170401004081040710003100021000400003000010000100001700000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011e0000293171a1171c1171d1171c1001a10018100171002b3171c1171d1171f1171d1001c1001a100181002d3171d1171f117211171f1001d1001c1001a1002b3171c1171d1171f1171d1001c1001a10018100
011e0020021120211209110041100211202112091100411204112041120b1100511205112051120c1100711005112051120c1100711207112071120e110091120911209112101100b11000112001120711002112
011e00001a7021a702130001c0001a7021a702130001c0001c7021c7021d000151001d7021d70218100171001d7021d7021a100181001f7021f7021c1001a10021702217021d1001c10018702187021f1001d100
011000001a7021a7021a100181001a7021a70218100171001c7021c70217100151001d7021d70218100171001d7021d7021a100181001f7021f702000000000021702217021d1001c10018702187020000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000001414714147201471e14722147201470000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 0c4a4344
01 0c0d4344
02 0c0d4344
00 0c0e4344

