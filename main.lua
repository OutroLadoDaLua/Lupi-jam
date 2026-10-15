require "palette"
require "sprites"

-- ============ ESTADO GLOBAL ============
local player  = { x = 240, y = 135, w = 10, h = 10 }
local enemies = {}
local chapter = 1
local chapter_clear_timer = 0   -- frames desde que limpou
local CLEAR_DELAY = 60          -- 1 segundo antes de avancar

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

-- ============ FABRICAS DE INIMIGO ============
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
        knockback = 12
    }
end

-- ============ SETUP POR CAPITULO ============
local function start_chapter(n)
    chapter = n
    chapter_clear_timer = 0

    if n == 1 then
        enemies = { make_weak_enemy(), make_weak_enemy(), make_weak_enemy() }
    elseif n == 2 then
        enemies = { make_strong_enemy() }
    end
end

local function init()
    player.x, player.y = 240, 135
    start_chapter(1)
end
init()

-- ============ MOVIMENTO DOS INIMIGOS ============
local function move_enemies()
    for _, e in ipairs(enemies) do
        e.x = clamp(e.x + math.random(-e.speed, e.speed), 0, 480 - e.w)
        e.y = clamp(e.y + math.random(-e.speed, e.speed), 0, 270 - e.h)
    end
end

-- ============ COLISAO ============
local function handle_collisions()
    for i = #enemies, 1, -1 do
        local e = enemies[i]
        if collides(player, e) then
            e.hp = e.hp - 1

            -- knockback do jogador (afasta do inimigo)
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

-- ============ TRANSICAO DE CAPITULO ============
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
            -- fim do jogo: reinicia do cap 1 (troque por tela de vitoria)
            start_chapter(1)
        end
    end
end

-- ============ DESENHO ============
local function draw_scene(frame)
    ui.cls(0)
    ui.camera(0, 0)
    ui.clip(0, 0, 480, 270)

    -- jogador
    ui.rectfill(player.x, player.y,
                player.x + player.w,
                player.y + player.h, 7)

    -- inimigos
    for _, e in ipairs(enemies) do
        ui.circfill(e.x + e.w/2, e.y + e.h/2, radius(e), e.color)
        -- barra de vida acima do inimigo (se tiver mais de 1 HP)
        if e.max_hp > 1 then
            local bar_w = e.w * 2
            ui.rectfill(e.x - e.w/2, e.y - 6,
                        e.x - e.w/2 + bar_w, e.y - 3, 2)
            local pct = e.hp / e.max_hp
            ui.rectfill(e.x - e.w/2, e.y - 6,
                        e.x - e.w/2 + bar_w * pct, e.y - 3, 11)
        end
    end

    ui.print("Cap " .. chapter .. " - Frame: " .. frame, 4, 4, 15)
    ui.print("Inimigos: " .. #enemies, 4, 14, 15)

    if #enemies == 0 and chapter_clear_timer > 0 then
        local txt = (chapter == 1) and "CAP 1 LIMPO!" or "VITORIA!"
        ui.print(txt, 190, 120, 11)
    end
end

-- ============ LOOP PRINCIPAL ============
function update(frame)
    -- paleta (obrigatorio todo frame)
    for i = 1, #Palette do
        ui.palset(i - 1, Palette[i])
    end

    -- input
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

    -- logica
    move_enemies()
    handle_collisions()
    update_chapter(frame)

    -- desenho
    draw_scene(frame)
end
