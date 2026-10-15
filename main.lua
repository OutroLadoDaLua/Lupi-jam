require "palette"
require "sprites"

-- ============ ESTADO ============
local player  = { x = 240, y = 135, w = 10, h = 10 }
local enemies = {}

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

-- ============ INIMIGOS ============
local function init_enemies(n)
    enemies = {}
    for _ = 1, (n or 3) do
        enemies[#enemies + 1] = {
            x = math.random(240, 480),
            y = math.random(135, 270),
            w = 10, h = 10
        }
    end
end

local function move_enemies()
    for _, e in ipairs(enemies) do
        e.x = clamp(e.x + math.random(-2, 2), 0, 480)
        e.y = clamp(e.y + math.random(-2, 2), 0, 270)
    end
end

-- ============ INICIALIZAÇÃO ============
local function init()
    player.x, player.y = 240, 135
    init_enemies(3)
end
init()

-- ============ LOOP PRINCIPAL ============
function update(frame)
    -- Registra paleta (obrigatório todo frame)
    for i = 1, #Palette do
        ui.palset(i - 1, Palette[i])
    end
    -- Registra sprites (se o módulo expõe isso)
    for i = 1, #Sprites do
        ui.sprset(i - 1, Sprites[i])
    end

    -- -------- INPUT --------
    local speed = 2
    if ui.btn(LEFT)  then player.x = player.x - speed end
    if ui.btn(RIGHT) then player.x = player.x + speed end
    if ui.btn(UP)    then player.y = player.y - speed end
    if ui.btn(DOWN)  then player.y = player.y + speed end

    -- Teclado (WASD) — lê 1 char por frame
    local key = ui.readtext()
    if     key == "w" then player.y = player.y - speed
    elseif key == "s" then player.y = player.y + speed
    elseif key == "a" then player.x = player.x - speed
    elseif key == "d" then player.x = player.x + speed
    end

    player.x = clamp(player.x, 0, 480)
    player.y = clamp(player.y, 0, 260)

    move_enemies()

    -- -------- COLISÃO --------
    for i = #enemies, 1, -1 do
        if collides(player, enemies[i]) then
            table.remove(enemies, i)
        end
    end

    -- -------- DESENHO --------
    ui.cls(0)
    ui.camera(0, 0)
    ui.clip(0, 0, 480, 270)

    -- jogador (retângulo preenchido)
    ui.rectfill(player.x, player.y,
                player.x + player.w,
                player.y + player.h, 7)

    -- inimigos (círculos preenchidos)
    for _, e in ipairs(enemies) do
        ui.circfill(e.x, e.y, radius(e), 8)
    end

    ui.print("Frame: " .. frame, 4, 4, 15)
    ui.print("Inimigos: " .. #enemies, 4, 14, 15)
end
