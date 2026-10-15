require "palette"
require "sprites"

-- ============ ASSETS DE TELA ============
local title_ref, intro_ref, final_ref
pcall(function() title_ref = require "assets.titulo" end)
pcall(function() intro_ref = require "assets.inicio" end)
pcall(function() final_ref = require "assets.final"  end)

-- ============ ESTADO GLOBAL ============
local player = {
    x = 240, y = 135, w = 10, h = 10,
    hp = 5, max_hp = 5,
    invuln = 0,
    invuln_time = 60
}
local enemies = {}
local projectiles = {}

local chapter = 1
local chapter_clear_timer = 0
local CLEAR_DELAY = 60

-- Maquina de estados
local state = "title"       -- title | intro1 | play1 | intro2 | play2
local state_timer = 0
local STATE_MIN_TIME = 30   -- 0.5s antes de aceitar "qualquer botao"

-- Escurecimento
local darkness            = 0
local MAX_DARK            = 0.75
local DECAY_PER_FRAME     = 0.0008
local PROJ_DARK_PER_FRAME = 0.0007
local HIT_DARK_BURST      = 0.06

-- Dano
local HIT_DAMAGE     = 1
local CONTACT_DAMAGE = 1

-- ============ UTIL ============
local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function radius(o) return math.max(o.w, o.h) / 2 end

local function collides(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx*dx + dy*dy) < (radius(a) + radius(b))
end

local function rect_overlap(a, b)
    return a.x < b.x + b.w and a.x + a.w > b.x
       and a.y < b.y + b.h and a.y + a.h > b.y
end

local function darken_color(c, f)
    if f <= 0 then return c end
    local r = math.floor(c / 1024) % 32
    local g = math.floor(c / 32)   % 32
    local b = c % 32
    local k = 1 - f
    r = math.floor(r * k)
    g = math.floor(g * k)
    b = math.floor(b * k)
    return r * 1024 + g * 32 + b
end

-- "Qualquer botao" — checa gamepad + teclado
local function any_button_pressed()
    local btns = { BTN_Z, BTN_X, BTN_F, BTN_G, BTN_Q, BTN_E,
                   LEFT, RIGHT, UP, DOWN }
    for _, b in ipairs(btns) do
        if b and ui.btnp and ui.btnp(b) then return true end
    end
    if ui.readtext then
        if ui.readtext() then return true end
    end
    return false
end

-- ============ FABRICAS ============
local function make_weak_enemy()
    return {
        x = math.random(0, 460),
        y = math.random(0, 250),
        w = 10, h = 10,
        hp = 1, max_hp = 1,
        speed = 5,
        color = 8
    }
end

local function make_strong_enemy()
    return {
        x = math.random(300, 450),
        y = math.random(150, 240),
        w = 20, h = 20,
        hp = 10, max_hp = 10,
        speed = 3,
        color = 9,
        knockback = 12,
        can_shoot = true,
        shoot_cd  = 60,
        shoot_rate = 90
    }
end

-- ============ PROJETEIS ============
local function spawn_projectile(from_x, from_y, to_x, to_y)
    local dx = to_x - from_x
    local dy = to_y - from_y
    local len = math.max(1, math.sqrt(dx*dx + dy*dy))
    local speed = 2.5
    projectiles[#projectiles + 1] = {
        x = from_x, y = from_y,
        w = 6, h = 3,
        vx = dx / len * speed,
        vy = dy / len * speed,
        life = 240,
        color = 4
    }
end

local function update_projectiles()
    for i = #projectiles, 1, -1 do
        local p = projectiles[i]
        p.x = p.x + p.vx
        p.y = p.y + p.vy
        p.life = p.life - 1

        local off = p.x < -20 or p.x > 500 or p.y < -20 or p.y > 290
        if p.life <= 0 or off then
            table.remove(projectiles, i)
        elseif rect_overlap(p, player) then
            table.remove(projectiles, i)
            if player.invuln <= 0 then
                player.hp = math.max(0, player.hp - HIT_DAMAGE)
                player.invuln = player.invuln_time
                darkness = math.min(MAX_DARK, darkness + HIT_DARK_BURST)
            end
        end
    end
end

-- ============ SETUP POR CAPITULO ============
local function start_chapter(n)
    chapter = n
    chapter_clear_timer = 0
    projectiles = {}

    if n == 1 then
        enemies = { make_weak_enemy(), make_weak_enemy(), make_weak_enemy(),
                    make_weak_enemy(), make_weak_enemy(), make_weak_enemy(),
                    make_weak_enemy(), make_weak_enemy(), make_weak_enemy(),
                    make_weak_enemy() }
    elseif n == 2 then
        enemies = { make_strong_enemy() }
    end
end

local function reset_player()
    player.x, player.y = 240, 135
    player.hp = player.max_hp
    player.invuln = 0
end

local function set_state(s)
    state = s
    state_timer = 0
    if s == "play1" then
        reset_player(); darkness = 0; start_chapter(1)
    elseif s == "play2" then
        reset_player(); darkness = 0; start_chapter(2)
    end
end

-- inicializa no titulo (nao no play1)
reset_player()
start_chapter(1)

-- ============ MOVIMENTO / TIRO ============
local function move_enemies()
    for _, e in ipairs(enemies) do
        e.x = clamp(e.x + math.random(-e.speed, e.speed), 0, 480 - e.w)
        e.y = clamp(e.y + math.random(-e.speed, e.speed), 0, 270 - e.h)

        if e.can_shoot then
            e.shoot_cd = (e.shoot_cd or 0) - 1
            if e.shoot_cd <= 0 then
                spawn_projectile(
                    e.x + e.w / 2, e.y + e.h / 2,
                    player.x + player.w / 2, player.y + player.h / 2
                )
                e.shoot_cd = e.shoot_rate
            end
        end
    end
end

-- ============ COLISAO CORPO-A-CORPO ============
local function handle_collisions()
    for i = #enemies, 1, -1 do
        local e = enemies[i]
        if collides(player, e) then
            e.hp = e.hp - 1

            if player.invuln <= 0 then
                player.hp = math.max(0, player.hp - CONTACT_DAMAGE)
                player.invuln = player.invuln_time
            end

            if e.knockback then
                local dx = player.x - e.x
                local dy = player.y - e.y
                local len = math.max(1, math.sqrt(dx*dx + dy*dy))
                player.x = player.x + (dx / len) * e.knockback
                player.y = player.y + (dy / len) * e.knockback
                player.x = clamp(player.x, 0, 480 - player.w)
                player.y = clamp(player.y, 0, 270 - player.h)
            end

            if e.hp <= 0 then
                table.remove(enemies, i)
            end
        end
    end
end

-- ============ TRANSICAO (so conta o timer; quem decide eh o loop) ============
local function update_chapter(frame)
    if #enemies > 0 then
        chapter_clear_timer = 0
    else
        chapter_clear_timer = chapter_clear_timer + 1
    end
end

-- ============ ESCURECIMENTO ============
local function update_darkness()
    darkness = darkness + #projectiles * PROJ_DARK_PER_FRAME
    darkness = darkness - DECAY_PER_FRAME
    darkness = math.max(0, math.min(MAX_DARK, darkness))
end

-- ============ INPUT DE JOGO ============
local function handle_input()
    local speed = 2
    if ui.btn(LEFT)  then player.x = player.x - speed end
    if ui.btn(RIGHT) then player.x = player.x + speed end
    if ui.btn(UP)    then player.y = player.y - speed end
    if ui.btn(DOWN)  then player.y = player.y + speed end

    if ui.readtext then
        local key = ui.readtext()
        if     key == "w" then player.y = player.y - speed
        elseif key == "s" then player.y = player.y + speed
        elseif key == "a" then player.x = player.x - speed
        elseif key == "d" then player.x = player.x + speed
        end
    end

    player.x = clamp(player.x, 0, 480 - player.w)
    player.y = clamp(player.y, 0, 270 - player.h)
end

-- ============ BARRA DE HP ============
local function draw_hp_bar(x, y, w, h)
    local pct = player.hp / player.max_hp

    ui.rectfill(x - 1, y - 1, x + w + 1, y + h + 1, 0)
    ui.rectfill(x, y, x + w, y + h, 2)

    local cor
    if     pct > 0.6 then cor = 11
    elseif pct > 0.3 then cor = 10
    else                  cor = 8
    end

    local fill_w = math.floor(w * pct)
    if fill_w > 0 then
        ui.rectfill(x, y, x + fill_w, y + h, cor)
    end

    ui.rect(x - 1, y - 1, x + w + 1, y + h + 1, 15)
    ui.print("HP " .. player.hp .. "/" .. player.max_hp, x + w + 6, y - 2, 15)
end

-- ============ TELAS ESTATICAS ============
local function draw_fullscreen(ref, fallback_text)
    ui.cls(0)
    ui.camera(0, 0)
    ui.clip(0, 0, 480, 270)
    if ref then
        ui.spr(ref, 0, 0)
    else
        ui.print(fallback_text or "?", 200, 120, 15)
    end
end

local function draw_press_any()
    if math.floor(state_timer / 30) % 2 == 0 then
        ui.print("Pressione qualquer botao", 160, 240, 15)
    end
end

-- ============ DESENHO DO JOGO ============
local function draw_scene(frame)
    ui.cls(0)
    ui.camera(0, 0)
    ui.clip(0, 0, 480, 270)

    local blink = player.invuln > 0 and (math.floor(player.invuln / 4) % 2 == 0)
    if not blink then
        ui.rectfill(player.x, player.y,
                    player.x + player.w,
                    player.y + player.h, 7)
    end

    for _, e in ipairs(enemies) do
        ui.circfill(e.x + e.w / 2, e.y + e.h / 2, radius(e), e.color)
        if e.max_hp > 1 then
            local bar_w = e.w * 2
            ui.rectfill(e.x - e.w / 2, e.y - 6,
                        e.x - e.w / 2 + bar_w, e.y - 3, 2)
            local pct = e.hp / e.max_hp
            ui.rectfill(e.x - e.w / 2, e.y - 6,
                        e.x - e.w / 2 + bar_w * pct, e.y - 3, 11)
        end
    end

    for _, p in ipairs(projectiles) do
        ui.rectfill(p.x, p.y, p.x + p.w, p.y + p.h, p.color)
    end

    ui.print("Cap " .. chapter .. " - Frame: " .. frame, 4, 4, 15)
    ui.print("Inimigos: " .. #enemies, 4, 14, 15)
    ui.print(string.format("Escuridao: %.0f%%", darkness * 100), 4, 24, 15)
    draw_hp_bar(10, 40, 60, 6)

    if #enemies == 0 and chapter_clear_timer > 0 then
        ui.print("CAP " .. chapter .. " LIMPO!", 180, 120, 11)
    end
end

-- ============ LOOP PRINCIPAL ============
function loop(frame)
    -- paleta (escurecida conforme darkness)
    update_darkness()
    for i = 1, #Palette do
        ui.palset(i - 1, darken_color(Palette[i], darkness))
    end
    if player.invuln > 0 then player.invuln = player.invuln - 1 end

    state_timer = state_timer + 1

    if state == "title" then
        draw_fullscreen(title_ref, "TITULO")
        draw_press_any()
        if state_timer > STATE_MIN_TIME and any_button_pressed() then
            set_state("intro1")
        end

    elseif state == "intro1" then
        draw_fullscreen(intro_ref, "INICIO")
        draw_press_any()
        if state_timer > STATE_MIN_TIME and any_button_pressed() then
            set_state("play1")
        end

    elseif state == "play1" then
        handle_input()
        move_enemies()
        update_projectiles()
        handle_collisions()
        update_chapter(frame)
        draw_scene(frame)
        if chapter_clear_timer >= CLEAR_DELAY then
            set_state("intro2")
        end

    elseif state == "intro2" then
        draw_fullscreen(final_ref, "FINAL")
        draw_press_any()
        if state_timer > STATE_MIN_TIME and any_button_pressed() then
            set_state("play2")
        end

    elseif state == "play2" then
        handle_input()
        move_enemies()
        update_projectiles()
        handle_collisions()
        update_chapter(frame)
        draw_scene(frame)
        if chapter_clear_timer >= CLEAR_DELAY then
            set_state("title")
        end
    end
end

-- alias para runtimes que chamam "update"
update = loop
