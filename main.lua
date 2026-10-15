require "palette"
require "sprites"

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

-- Escurece cor RGB555
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

-- ============ FABRICAS ============
local function make_weak_enemy()
    return {
        x = math.random(240, 460),
        y = math.random(135, 250),
        w = 10, h = 10,
        hp = 1, max_hp = 1,
        speed = 2,
        color = 8
    }
end

local function make_strong_enemy()
    return {
        x = math.random(300, 450),
        y = math.random(150, 240),
        w = 20, h = 20,
        hp = 5, max_hp = 5,
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
        enemies = { make_weak_enemy(), make_weak_enemy(), make_weak_enemy() }
    elseif n == 2 then
        enemies = { make_strong_enemy() }
    end
end

local function init()
    player.x, player.y = 240, 135
    player.hp = player.max_hp
    player.invuln = 0
    darkness = 0
    start_chapter(1)
end
init()

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

-- ============ TRANSICAO ============
local function update_chapter(frame)
    if #enemies > 0 then
        chapter_clear_timer = 0
        return
    end
    chapter_clear_timer = chapter_clear_timer + 1
    if chapter_clear_timer >= CLEAR_DELAY then
        if chapter == 1 then
            start_chapter(2)
        else
            start_chapter(1)
        end
    end
end

-- ============ ESCURECIMENTO ============
local function update_darkness()
    darkness = darkness + #projectiles * PROJ_DARK_PER_FRAME
    darkness = darkness - DECAY_PER_FRAME
    darkness = math.max(0, math.min(MAX_DARK, darkness))
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

-- ============ DESENHO ============
local function draw_scene(frame)
    ui.cls(0)
    ui.camera(0, 0)
    ui.clip(0, 0, 480, 270)

    -- jogador (pisca durante i-frame)
    local blink = player.invuln > 0 and (math.floor(player.invuln / 4) % 2 == 0)
    if not blink then
        ui.rectfill(player.x, player.y,
                    player.x + player.w,
                    player.y + player.h, 7)
    end

    -- inimigos
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

    -- projeteis
    for _, p in ipairs(projectiles) do
        ui.rectfill(p.x, p.y, p.x + p.w, p.y + p.h, p.color)
    end

    -- HUD
    ui.print("Cap " .. chapter .. " - Frame: " .. frame, 4, 4, 15)
    ui.print("Inimigos: " .. #enemies, 4, 14, 15)
    ui.print(string.format("Escuridao: %.0f%%", darkness * 100), 4, 24, 15)

    -- Barra de HP no canto superior esquerdo
    draw_hp_bar(10, 40, 60, 6)

    if #enemies == 0 and chapter_clear_timer > 0 then
        local txt = (chapter == 1) and "CAP 1 LIMPO!" or "VITORIA!"
        ui.print(txt, 190, 120, 11)
    end
end

-- ============ LOOP PRINCIPAL ============
function update(frame)
    -- 1) escuridao
    update_darkness()

    -- 2) registra paleta escurecida
    for i = 1, #Palette do
        ui.palset(i - 1, darken_color(Palette[i], darkness))
    end

    -- 3) tick do i-frame
    if player.invuln > 0 then player.invuln = player.invuln - 1 end

    -- 4) input
    local speed = 2
    if ui.btn(LEFT)  then player.x = player.x - speed end
    if ui.btn(RIGHT) then player.x = player.x + speed end
    if ui.btn(UP)    then player.y = player.y - speed end
    if ui.btn(DOWN)  then player.y = player.y + speed end

    local key = ui.readtext()
    if     key == "w" then player.y = player.y - speed
    elseif key == "s" then player.y = player.y + speed
    elseif key == "a" then player.x = player.x - speed
    elseif key == "d" then player.x = player.x + speed
    end

    player.x = clamp(player.x, 0, 480 - player.w)
    player.y = clamp(player.y, 0, 270 - player.h)

    -- 5) logica
    move_enemies()
    update_projectiles()
    handle_collisions()
    update_chapter(frame)

    -- 6) desenho
    draw_scene(frame)
end
