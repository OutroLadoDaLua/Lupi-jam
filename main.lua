require "Palette"
require "Sprites"
local function try_require(name)
    local ok, res = pcall(require, name)
    if ok then
        ui.log("OK: " .. name .. " (" .. type(res) .. ")")
        return res
    end
    ui.log("FALHOU: " .. name .. " -> " .. tostring(res))
    return nil
end

-- ============================================================
-- CONFIG DE ASSETS  (AJUSTE AQUI)
-- ============================================================
-- Cada entrada: modulo gerado do PNG, quantos frames tem (tiles),
-- velocidade (frames de jogo por frame de animacao) e tamanho do
-- sprite em pixels (sw, sh) para centralizar na hitbox.
-- Se o modulo nao existir, o jogo usa formas simples (nao crasha).
local ASSET_CFG = {
    jogador_andar  = { mod = "assets.jogador.correndo", frames = 4, speed = 6, sw = 16, sh = 16 },
    jogador_ataque = { mod = "assets.jogador.ataque",   frames = 4, speed = 4, sw = 16, sh = 16 },
    inimigo_andar  = { mod = "assets.inimigo.correndo", frames = 4, speed = 8, sw = 16, sh = 16 },
    inimigo_ataque = { mod = "assets.inimigo.ataque",   frames = 4, speed = 6, sw = 16, sh = 16 },
}

-- Telas cheias (imagem esperada: 240x135, centralizada em 480x270)
local SCREEN_W, SCREEN_H = 240, 135

-- Se o flip de tile nao funcionar, troque para false para usar
-- o parametro flip_x de ui.tile (documentacao da API).
local FLIP_BY_TILE_BIT = true

local function try_require(name)
    local ok, res = pcall(require, name)
    if ok then return res end
    return nil
end

local title_ref = try_require("assets.titulo")
local intro_ref = try_require("assets.inicio")
local final_ref = try_require("assets.final")

local SPR = {}
for key, cfg in pairs(ASSET_CFG) do
    SPR[key] = {
        ref = try_require(cfg.mod),
        frames = cfg.frames, speed = cfg.speed,
        sw = cfg.sw, sh = cfg.sh,
    }
end

-- Desenha frame de animacao. `frame` (opcional) forca o indice;
-- senao usa `t` (contador) e a velocidade. Retorna true se desenhou.
local function draw_sprite(s, cx, cy, w, h, flip, t, frame)
    if not s or not s.ref then return false end
    local x = cx - (s.sw - w) / 2
    local y = cy - (s.sh - h)
    if s.frames > 1 then
        local f = frame or (math.floor(t / s.speed) % s.frames)
        f = ui.mid(0, f, s.frames - 1)
        if FLIP_BY_TILE_BIT then
            ui.tile(s.ref, f + (flip and 1024 or 0), x, y)
        else
            ui.tile(s.ref, f, x, y, flip)
        end
    else
        ui.spr(s.ref, x, y, flip)
    end
    return true
end

-- ============================================================
-- ESTADO GLOBAL
-- ============================================================
local player = {
    x = 240, y = 135, w = 10, h = 10,
    hp = 5, max_hp = 5,
    invuln = 0, invuln_time = 60,
    moving = false,
}
local enemies = {}
local projectiles = {}

local chapter = 1
local chapter_clear_timer = 0
local CLEAR_DELAY = 60

-- Maquina de estados: title, intro1, play1, intro2, play2, ending, gameover
local state = "title"
local state_timer = 0
local STATE_MIN_TIME = 30
local anim_t = 0

-- Escurecimento
local darkness            = 0
local MAX_DARK            = 0.75
local DECAY_PER_FRAME     = 0.0008
local PROJ_DARK_PER_FRAME = 0.0007
local HIT_DARK_BURST      = 0.06

-- Dano
local HIT_DAMAGE     = 1
local CONTACT_DAMAGE = 1
local ATTACK_DAMAGE  = 2

-- Ataque
local attack = {
    active = false, timer = 0, duration = 15,
    cooldown = 0, cooldown_max = 25,
    range = 18, w = 20, h = 20,
    hit = {},   -- inimigos ja acertados neste golpe
}

local facing = { x = 1, y = 0 }
local gameover = false

-- ============================================================
-- UTIL
-- ============================================================
local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function radius(o) return math.max(o.w, o.h) / 2 end

local function rect_overlap(a, b)
    return a.x < b.x + b.w and a.x + a.w > b.x
       and a.y < b.y + b.h and a.y + a.h > b.y
end

local function dist(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
end

-- Escurece cor BGR555 (0BBBBBGGGGGRRRRR).
-- Se as cores sairem invertidas no console, troque b e r.
local function darken_color(c, f)
    if f <= 0 then return c end
    local b = math.floor(c / 1024) % 32
    local g = math.floor(c / 32) % 32
    local r = c % 32
    local k = 1 - f
    r = math.floor(r * k)
    g = math.floor(g * k)
    b = math.floor(b * k)
    return b * 1024 + g * 32 + r
end

-- Esvazia a fila de teclado para nao acumular caracteres
local function drain_text()
    if not ui.readtext then return false end
    local got = false
    local n = 0
    while ui.readtext() and n < 32 do
        got = true
        n = n + 1
    end
    return got
end

-- BTN_X NAO existe no Lupi.
local ANY_BTNS = { BTN_Z, BTN_Q, BTN_E, BTN_F, BTN_G, LEFT, RIGHT, UP, DOWN }
local function any_button_pressed()
    local pressed = false
    for _, b in ipairs(ANY_BTNS) do
        if b and ui.btnp(b) then pressed = true end
    end
    if drain_text() then pressed = true end
    return pressed
end

-- ============================================================
-- FABRICAS
-- ============================================================
local function random_far_from_player(x0, x1, y0, y1, w, h)
    local x, y
    for _ = 1, 20 do
        x = math.random(x0, x1)
        y = math.random(y0, y1)
        if dist(x + w / 2, y + h / 2, player.x + player.w / 2, player.y + player.h / 2) > 80 then
            break
        end
    end
    return x, y
end

local function new_wander(e)
    local a = math.random() * math.pi * 2
    e.dx, e.dy = math.cos(a), math.sin(a)
    e.turn = math.random(30, 90)
end

local function make_weak_enemy()
    local x, y = random_far_from_player(0, 460, 0, 250, 10, 10)
    local e = {
        x = x, y = y, w = 10, h = 10,
        hp = 1, max_hp = 1,
        speed = 0.9, chase = 0.0,
        color = 8, flip = false,
    }
    new_wander(e)
    return e
end

local function make_strong_enemy()
    local x, y = random_far_from_player(300, 450, 150, 240, 20, 20)
    local e = {
        x = x, y = y, w = 20, h = 20,
        hp = 10, max_hp = 10,
        speed = 0.6, chase = 0.6,
        color = 9, flip = false,
        knockback = 12,
        can_shoot = true, shoot_cd = 60, shoot_rate = 90,
    }
    new_wander(e)
    return e
end

-- ============================================================
-- PROJETEIS
-- ============================================================
local function spawn_projectile(from_x, from_y, to_x, to_y)
    local dx, dy = to_x - from_x, to_y - from_y
    local len = math.max(1, math.sqrt(dx * dx + dy * dy))
    local speed = 2.5
    projectiles[#projectiles + 1] = {
        x = from_x, y = from_y, w = 6, h = 3,
        vx = dx / len * speed, vy = dy / len * speed,
        life = 240, color = 4,
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

-- ============================================================
-- SETUP
-- ============================================================
local function start_chapter(n)
    chapter = n
    chapter_clear_timer = 0
    projectiles = {}
    enemies = {}
    if n == 1 then
        for _ = 1, 10 do enemies[#enemies + 1] = make_weak_enemy() end
    elseif n == 2 then
        enemies[1] = make_strong_enemy()
    end
end

local function reset_player()
    player.x, player.y = 240, 135
    player.hp = player.max_hp
    player.invuln = 0
    player.moving = false
end

local function set_state(s)
    state = s
    state_timer = 0
    if s == "play1" or s == "play2" then
        reset_player()
        darkness = 0
        attack.active = false
        attack.cooldown = 0
        attack.timer = 0
        attack.hit = {}
        gameover = false
        start_chapter(s == "play1" and 1 or 2)
    end
end

reset_player()
start_chapter(1)

-- ============================================================
-- INIMIGOS
-- ============================================================
local function move_enemies()
    local pcx = player.x + player.w / 2
    local pcy = player.y + player.h / 2

    for _, e in ipairs(enemies) do
        e.turn = e.turn - 1
        if e.turn <= 0 then new_wander(e) end

        local ecx, ecy = e.x + e.w / 2, e.y + e.h / 2
        local vx, vy = e.dx, e.dy

        if e.chase > 0 then
            local d = math.max(1, dist(ecx, ecy, pcx, pcy))
            vx = vx * (1 - e.chase) + (pcx - ecx) / d * e.chase
            vy = vy * (1 - e.chase) + (pcy - ecy) / d * e.chase
        end

        e.x = e.x + vx * e.speed
        e.y = e.y + vy * e.speed
        if vx < -0.1 then e.flip = true elseif vx > 0.1 then e.flip = false end

        -- bateu na parede: escolhe nova direcao
        if e.x < 0 or e.x > 480 - e.w or e.y < 0 or e.y > 270 - e.h then
            new_wander(e)
        end
        e.x = clamp(e.x, 0, 480 - e.w)
        e.y = clamp(e.y, 0, 270 - e.h)

        if e.can_shoot then
            e.shoot_cd = e.shoot_cd - 1
            if e.shoot_cd <= 0 then
                spawn_projectile(ecx, ecy, pcx, pcy)
                e.shoot_cd = e.shoot_rate
            end
        end
    end
end

-- Contato: so machuca o jogador (inimigos so morrem pelo ataque)
local function handle_collisions()
    if player.invuln > 0 then return end
    for _, e in ipairs(enemies) do
        if rect_overlap(player, e) then
            player.hp = math.max(0, player.hp - CONTACT_DAMAGE)
            player.invuln = player.invuln_time

            if e.knockback then
                local dx = (player.x + player.w / 2) - (e.x + e.w / 2)
                local dy = (player.y + player.h / 2) - (e.y + e.h / 2)
                local len = math.max(1, math.sqrt(dx * dx + dy * dy))
                player.x = clamp(player.x + dx / len * e.knockback, 0, 480 - player.w)
                player.y = clamp(player.y + dy / len * e.knockback, 0, 270 - player.h)
            end
            break
        end
    end
end

-- ============================================================
-- ATAQUE
-- ============================================================
local function try_attack()
    if attack.cooldown > 0 or attack.active then return end
    attack.active = true
    attack.timer = attack.duration
    attack.cooldown = attack.cooldown_max
    attack.hit = {}
end

local function attack_hitbox()
    local cx = player.x + player.w / 2
    local cy = player.y + player.h / 2
    return {
        x = cx + facing.x * attack.range - attack.w / 2,
        y = cy + facing.y * attack.range - attack.h / 2,
        w = attack.w, h = attack.h,
    }
end

local function update_attack()
    if attack.cooldown > 0 then attack.cooldown = attack.cooldown - 1 end
    if not attack.active then return end

    attack.timer = attack.timer - 1
    if attack.timer <= 0 then
        attack.active = false
        return
    end

    -- invulneravel durante o golpe
    if player.invuln < attack.timer then player.invuln = attack.timer end

    local hb = attack_hitbox()
    for i = #enemies, 1, -1 do
        local e = enemies[i]
        if not attack.hit[e] and rect_overlap(hb, e) then
            attack.hit[e] = true
            e.hp = e.hp - ATTACK_DAMAGE
            if e.hp <= 0 then table.remove(enemies, i) end
        end
    end
end

-- ============================================================
-- TRANSICAO / GAMEOVER / ESCURECIMENTO
-- ============================================================
local function update_chapter()
    if #enemies > 0 then
        chapter_clear_timer = 0
    else
        chapter_clear_timer = chapter_clear_timer + 1
    end
end

local function check_gameover()
    if player.hp <= 0 and not gameover then gameover = true end
end

local function update_darkness()
    darkness = darkness + #projectiles * PROJ_DARK_PER_FRAME
    darkness = darkness - DECAY_PER_FRAME
    darkness = math.max(0, math.min(MAX_DARK, darkness))
end

-- ============================================================
-- INPUT  (ui.btn ja cobre A/W/S/D no simulador)
-- ============================================================
local function handle_input()
    local speed = 2
    local moved = false

    if ui.btn(LEFT)  then player.x = player.x - speed; facing.x, facing.y = -1, 0; moved = true end
    if ui.btn(RIGHT) then player.x = player.x + speed; facing.x, facing.y =  1, 0; moved = true end
    if ui.btn(UP)    then player.y = player.y - speed; facing.x, facing.y =  0,-1; moved = true end
    if ui.btn(DOWN)  then player.y = player.y + speed; facing.x, facing.y =  0, 1; moved = true end

    player.moving = moved
    drain_text()

    player.x = clamp(player.x, 0, 480 - player.w)
    player.y = clamp(player.y, 0, 270 - player.h)

    if ui.btnp(BTN_Z) then try_attack() end
end

-- ============================================================
-- HUD
-- ============================================================
local function draw_hp_bar(x, y, w, h)
    local pct = player.hp / player.max_hp

    ui.rectfill(x - 1, y - 1, x + w + 1, y + h + 1, 0)
    ui.rectfill(x, y, x + w, y + h, 2)

    local cor
    if     pct > 0.6 then cor = 11
    elseif pct > 0.3 then cor = 10
    else                  cor = 8 end

    local fill_w = math.floor(w * pct)
    if fill_w > 0 then ui.rectfill(x, y, x + fill_w, y + h, cor) end

    ui.rect(x - 1, y - 1, x + w + 1, y + h + 1, 15)
    ui.print("HP " .. player.hp .. "/" .. player.max_hp, x + w + 6, y - 2, 15)
end

-- ============================================================
-- TELAS ESTATICAS
-- ============================================================
local function draw_fullscreen(ref, fallback_text)
    ui.cls(0)
    ui.camera(0, 0)
    ui.clip(0, 0, 480, 270)
    if ref then
        ui.spr(ref, (480 - SCREEN_W) / 2, (270 - SCREEN_H) / 2)
    else
        ui.print(fallback_text or "?", 200, 120, 15)
    end
end

local function draw_press_any(y)
    if math.floor(state_timer / 30) % 2 == 0 then
        ui.print("Pressione qualquer botao", 160, y or 240, 15)
    end
end

-- ============================================================
-- DESENHO DO JOGO
-- ============================================================
local function draw_scene(frame)
    ui.cls(0)
    ui.camera(0, 0)
    ui.clip(0, 0, 480, 270)

    -- inimigos
    for _, e in ipairs(enemies) do
        local drawn = draw_sprite(SPR.inimigo_andar, e.x, e.y, e.w, e.h, e.flip, anim_t)
        if not drawn then
            ui.circfill(e.x + e.w / 2, e.y + e.h / 2, radius(e), e.color)
        end
        if e.max_hp > 1 then
            local bx = e.x + e.w / 2 - e.w
            local bw = e.w * 2
            ui.rectfill(bx, e.y - 8, bx + bw, e.y - 5, 2)
            ui.rectfill(bx, e.y - 8, bx + bw * (e.hp / e.max_hp), e.y - 5, 11)
        end
    end

    -- jogador (pisca durante i-frame, mas nao durante o golpe)
    local blink = player.invuln > 0 and not attack.active
                  and (math.floor(player.invuln / 4) % 2 == 0)
    if not blink then
        local flip = facing.x < 0
        local drawn
        if attack.active then
            local prog = (attack.duration - attack.timer) / attack.duration
            local f = math.floor(prog * SPR.jogador_ataque.frames)
            drawn = draw_sprite(SPR.jogador_ataque, player.x, player.y,
                                player.w, player.h, flip, anim_t, f)
        elseif player.moving then
            drawn = draw_sprite(SPR.jogador_andar, player.x, player.y,
                                player.w, player.h, flip, anim_t)
        else
            -- parado: primeiro frame da animacao de andar
            drawn = draw_sprite(SPR.jogador_andar, player.x, player.y,
                                player.w, player.h, flip, anim_t, 0)
        end
        if not drawn then
            ui.rectfill(player.x, player.y, player.x + player.w, player.y + player.h, 7)
        end
    end

    -- hitbox do ataque (so aparece se nao houver sprite de ataque)
    if attack.active and not SPR.jogador_ataque.ref then
        local hb = attack_hitbox()
        ui.rectfill(hb.x, hb.y, hb.x + hb.w, hb.y + hb.h, 15)
    end

    -- projeteis
    for _, p in ipairs(projectiles) do
        ui.rectfill(p.x, p.y, p.x + p.w, p.y + p.h, p.color)
    end

    -- HUD
    ui.print("Cap " .. chapter .. " - Frame: " .. frame, 4, 4, 15)
    ui.print("Inimigos: " .. #enemies, 4, 14, 15)
    ui.print(string.format("Escuridao: %.0f%%", darkness * 100), 4, 24, 15)
    draw_hp_bar(10, 40, 60, 6)

    if #enemies == 0 and chapter_clear_timer > 0 then
        ui.print("CAP " .. chapter .. " LIMPO!", 180, 120, 11)
    end
end

-- ============================================================
-- LOOP PRINCIPAL
-- ============================================================
function loop(frame)
    anim_t = anim_t + 1

    -- paleta escurecida (obrigatorio todo frame)
    update_darkness()
    for i = 1, #Palette do
        ui.palset(i - 1, darken_color(Palette[i], darkness))
    end
    if player.invuln > 0 then player.invuln = player.invuln - 1 end

    state_timer = state_timer + 1
    local ready = state_timer > STATE_MIN_TIME

    if state == "title" then
        draw_fullscreen(title_ref, "TITULO")
        draw_press_any()
        if any_button_pressed() and ready then set_state("intro1") end

    elseif state == "intro1" then
        draw_fullscreen(intro_ref, "INICIO")
        draw_press_any()
        if any_button_pressed() and ready then set_state("play1") end

    elseif state == "play1" or state == "play2" then
        handle_input()
        update_attack()
        move_enemies()
        update_projectiles()
        handle_collisions()
        update_chapter()
        draw_scene(frame)

        check_gameover()
        if gameover then
            set_state("gameover")
        elseif chapter_clear_timer >= CLEAR_DELAY then
            set_state(state == "play1" and "intro2" or "ending")
        end

    elseif state == "intro2" then
        ui.cls(0)
        ui.camera(0, 0)
        ui.clip(0, 0, 480, 270)
        ui.print("CAPITULO 2", 200, 115, 15)
        draw_press_any(145)
        if any_button_pressed() and ready then set_state("play2") end

    elseif state == "ending" then
        draw_fullscreen(final_ref, "FINAL")
        draw_press_any()
        if any_button_pressed() and ready then set_state("title") end

    elseif state == "gameover" then
        ui.cls(0)
        ui.print("GAME OVER", 200, 120, 8)
        draw_press_any(145)
        if any_button_pressed() and ready then set_state("title") end
    end
end

-- alias para runtimes que chamam "update" direto (game.lua redefine isso)
update = loop
