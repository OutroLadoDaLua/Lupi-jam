# Documentação da API do Lupi / Lupinho

**Versão:** Baseada no repositório oficial `lupi-org-br/lupinho` (v1.2.0)
**Última atualização:** Outubro de 2026

---

## Índice

1. [Introdução](#1-introdução)
2. [Especificações Técnicas](#2-especificações-técnicas)
3. [Sistema de Cores (BGR555)](#3-sistema-de-cores-bgr555)
4. [Estrutura do Projeto](#4-estrutura-do-projeto)
5. [Ciclo Principal](#5-ciclo-principal)
6. [API Gráfica](#6-api-gráfica)
7. [API de Entrada](#7-api-de-entrada)
8. [Constantes Globais](#8-constantes-globais)
9. [Utilitários](#9-utilitários)
10. [Exemplo Completo](#10-exemplo-completo)
11. [Compilando e Testando](#11-compilando-e-testando)
12. [Migrando do Pico-8](#12-migrando-do-pico-8)

---

## 1. Introdução

**Lupinho** é o simulador web do **Lupi**, um console de jogos brasileiro. Ele roda direto no navegador usando **WebAssembly**, permitindo escrever e jogar games com uma API simples em **Lua 5.4**.

O simulador é open-source (licença MIT) e construído sobre a biblioteca gráfica **Raylib**.

---

## 2. Especificações Técnicas

| Propriedade | Valor |
|---|---|
| Resolução | 480 × 270 pixels (16:9 widescreen) |
| Cores | Paleta indexada com 256 cores |
| Formato de cor | **BGR555** (5 bits por canal, Big Endian) |
| Frame rate | 60 FPS |
| Linguagem de script | Lua 5.4 |
| Plataforma | WebAssembly (via Emscripten) |
| Linguagem do motor | C99 |
| Biblioteca gráfica | Raylib |
| Hardware real | ESP32-S3 n16r8 @ 240 MHz + RP2350 OC @ 345 MHz |

---

## 3. Sistema de Cores (BGR555)

O Lupi usa um formato de **16 bits**, sendo que apenas **15 bits** são usados. O bit mais significativo é ignorado.

> ⚠️ **Atenção:** Ao contrário do que algumas documentações antigas dizem, o Lupinho usa **BGR555**, não RGB555. A ordem dos canais é **azul → verde → vermelho**, em **Big Endian**.

**Formato binário:** `0BBBBBGGGGGRRRRR`

- **B (Blue):** 5 bits (0–31)
- **G (Green):** 5 bits (0–31)
- **R (Red):** 5 bits (0–31)

### Conversão de RGB para BGR555

Se você tem uma cor no formato RGB888 (ex.: `0xRRGGBB`), a conversão é:

```lua
function rgb_to_bgr555(hex)
    local r = math.floor(hex / 0x10000) % 0x100
    local g = math.floor(hex / 0x100) % 0x100
    local b = hex % 0x100
    return (math.floor(b / 8) << 10) | (math.floor(g / 8) << 5) | math.floor(r / 8)
end
```

**Exemplo prático:**

```lua
-- RGB 0x73428C → BGR555
-- R = 0x73, G = 0x42, B = 0x8C
-- R5 = 0x73 >> 3 = 0x0E
-- G5 = 0x42 >> 3 = 0x08
-- B5 = 0x8C >> 3 = 0x11
-- Resultado: (0x11 << 10) | (0x08 << 5) | 0x0E = 0x4510E... (16 bits: 0x510E)
```

### Função de paleta

A paleta deve ser **registrada a cada frame** dentro de `update()`:

```lua
function update()
    for i = 1, #Palette do
        ui.palset(i - 1, Palette[i])
    end
    -- ... resto do jogo
end
```

---

## 4. Estrutura do Projeto

Um projeto Lupinho típico tem a seguinte estrutura:

```
meu-jogo/
├── game.lua              # Ponto de entrada (define update())
├── main.lua              # Lógica principal (opcional)
├── palette.lua           # Definição da paleta
├── sprites.lua           # Carregamento de sprites
├── lupi_manifest.txt     # Lista de arquivos a carregar
├── img/                  # Bitmaps (sprites)
└── map/                  # Dados de tilemap
```

### `lupi_manifest.txt`

Lista os arquivos Lua e assets que o simulador deve carregar. Um arquivo por linha:

```
game.lua
main.lua
palette.lua
sprites.lua
img/player.png
map/fase1.map
```

### `lupi.yaml` (metadados do jogo)

```yaml
name: Meu Jogo
public: true
version: 1.2
```

### Ponto de entrada — `game.lua`

O simulador chama `update()` a cada frame. Um padrão comum é delegar para uma função `loop()`:

```lua
require "main"

Frame = 0

function update()
    Frame = Frame + 1
    loop(Frame)
end
```

---

## 5. Ciclo Principal

### `update()`

Chamada **60 vezes por segundo** (uma vez por frame). Toda a lógica do jogo — input, atualização de estado e desenho — acontece aqui.

```lua
function update()
    -- 1. Registrar paleta (obrigatório)
    -- 2. Ler input
    -- 3. Atualizar lógica
    -- 4. Desenhar
end
```

> ℹ️ Não existe `_init()`, `_update()` ou `_draw()` separados como no Pico-8. O código fora de `update()` roda **uma vez** na carga do script (inicialização).

---

## 6. API Gráfica

Todas as funções de desenho estão no namespace `ui.*` e usam **índices de paleta** (0–255) para cores.

### 6.1 Tela

#### `ui.cls(color)`

Limpa a tela com a cor da paleta especificada.

```lua
ui.cls(0)   -- Preto
ui.cls(12)  -- Azul
```

---

#### `ui.camera(x, y)`

Define o deslocamento da câmera para todas as operações de desenho subsequentes. Sem argumentos, reseta a câmera para (0, 0).

```lua
ui.camera(player.x - 240, player.y - 135)
-- ... desenha o mundo ...
ui.camera()  -- Reseta
```

---

#### `ui.clip(x, y, w, h)`

Define a região de recorte (clipping). Apenas pixels dentro dessa região serão desenhados. Sem argumentos, reseta o clip.

```lua
ui.clip(0, 0, 480, 270)
ui.clip()  -- Reseta
```

---

#### `ui.fillp(b1, b2, ...)`

Define um padrão de preenchimento 8×8 (1 byte por linha). Sem argumentos, volta ao preenchimento sólido.

```lua
-- Padrão xadrez
ui.fillp(0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55)
ui.rectfill(0, 0, 100, 100, 7)
ui.fillp()  -- Volta ao sólido
```

---

### 6.2 Primitivas

#### `ui.rect(x1, y1, x2, y2, color)`

Desenha um retângulo (apenas contorno).

```lua
ui.rect(50, 50, 130, 130, 1)
```

---

#### `ui.rectfill(x1, y1, x2, y2, color)`

Desenha um retângulo preenchido.

```lua
ui.rectfill(50, 50, 100, 100, 8)
```

---

#### `ui.draw_rect(x, y, w, h, filled, color)`

Desenha um retângulo usando largura/altura em vez de coordenadas.

| Parâmetro | Descrição |
|---|---|
| `x, y` | Canto superior esquerdo |
| `w, h` | Largura e altura |
| `filled` | `true` para preenchido, `false` para contorno |
| `color` | Índice da paleta |

```lua
ui.draw_rect(50, 50, 80, 50, true, 8)   -- Preenchido
ui.draw_rect(50, 50, 80, 50, false, 7)  -- Contorno
```

---

#### `ui.circfill(x, y, radius, color)`

Desenha um círculo preenchido.

```lua
ui.circfill(200, 100, 20, 3)
```

---

#### `ui.draw_circle(cx, cy, r, filled, color, border, border_color)`

Desenha um círculo com opção de borda.

| Parâmetro | Descrição |
|---|---|
| `cx, cy` | Centro |
| `r` | Raio |
| `filled` | `true` = preenchido, `false` = contorno |
| `color` | Cor de preenchimento |
| `border` | Largura da borda (opcional) |
| `border_color` | Cor da borda (opcional) |

```lua
ui.draw_circle(240, 135, 30, true, 11, 2, 7)  -- Verde com borda branca
```

---

#### `ui.trisfill(x1, y1, x2, y2, x3, y3, color)`

Desenha um triângulo preenchido.

```lua
ui.trisfill(20, 250, 100, 250, 55, 350, 4)
```

---

#### `ui.line(x1, y1, x2, y2, color)`

Desenha uma linha entre dois pontos.

```lua
ui.line(0, 0, 480, 270, 6)
```

---

### 6.3 Texto

#### `ui.print(text, x, y, color)`

Desenha um texto usando a fonte bitmap embutida.

| Parâmetro | Descrição |
|---|---|
| `text` | String a desenhar |
| `x, y` | Posição na tela |
| `color` | Índice da paleta |

```lua
ui.print("Oi, Lupi!", 32, 32, Palette.hex(0x73428C))
```

> ⚠️ **Ordem dos argumentos:** texto → x → y → cor. Inverter isso é um erro comum.

---

### 6.4 Sprites e Tiles

#### `ui.spr(sprite_table, x, y, flipped)`

Desenha um sprite a partir de uma tabela de sprites.

| Parâmetro | Descrição |
|---|---|
| `sprite_table` | Tabela de dados do sprite sheet |
| `x, y` | Posição na tela |
| `flipped` | `true` para inverter horizontalmente (opcional) |

```lua
ui.spr(player_sprite, 100, 100)
ui.spr(player_sprite, 100, 100, true)  -- Espelhado
```

> ⚠️ **Diferença importante em relação ao Pico-8:** sprites são **referências a tabelas**, não índices numéricos.

---

#### `ui.tile(tileset_table, tile_index, x, y)`

Desenha um tile específico de um tileset.

| Parâmetro | Descrição |
|---|---|
| `tileset_table` | Tabela do tileset |
| `tile_index` | Índice do tile |
| `x, y` | Posição na tela |

> 💡 **Truque:** o **bit 10** do `tile_index` inverte o tile horizontalmente. Basta somar `1024` ao índice para flipar.

```lua
ui.tile(tileset, 5, 200, 150)         -- Tile 5 normal
ui.tile(tileset, 5 + 1024, 200, 150)  -- Tile 5 espelhado
```

---

### 6.5 Mapas

#### `ui.map(layer_table, cam_x, cam_y)`

Desenha uma camada de tilemap com suporte a câmera.

| Parâmetro | Descrição |
|---|---|
| `layer_table` | Tabela com dados da camada do mapa |
| `cam_x, cam_y` | Offset da câmera |

```lua
local cam_x = 240 - player.x
local cam_y = 135 - player.y

ui.map(mapa_fase_1, cam_x, cam_y)
```

---

### 6.6 Paleta

#### `ui.palset(index, bgr555)`

Define uma cor da paleta no índice especificado.

| Parâmetro | Descrição |
|---|---|
| `index` | Índice da cor (0–255) |
| `bgr555` | Valor da cor em BGR555 |

```lua
ui.palset(8, 0x03E0)  -- Verde puro
```

> ⚠️ **A paleta deve ser registrada a cada frame.** Se você esquecer, as cores ficarão erradas.

---

## 7. API de Entrada

### 7.1 Controle e Teclado

#### `ui.btn(button, pad)`

Verifica se um botão está sendo mantido pressionado. Funciona com gamepad **e** teclado.

| Parâmetro | Descrição |
|---|---|
| `button` | Constante do botão (`UP`, `DOWN`, `LEFT`, `RIGHT`, `BTN_Z`, `BTN_Q`, `BTN_E`, `BTN_F`, `BTN_G`) |
| `pad` | Índice do jogador (opcional, padrão 0) |

```lua
if ui.btn(LEFT) then player.x = player.x - 2 end
if ui.btn(RIGHT) then player.x = player.x + 2 end
if ui.btn(BTN_Z, 1) then jump(1) end  -- Segundo jogador
```

---

#### `ui.btnp(button, pad)`

Verifica se um botão foi **pressionado neste frame** (detecção de borda). Útil para ações que não devem repetir enquanto o botão estiver segurado.

```lua
if ui.btnp(BTN_Z) then
    ui.log("Botão Z pressionado!")
    shoot()
end
```

---

### 7.2 Teclas padrão do simulador

| Ação | Tecla |
|---|---|
| Mover | **A / W / S / D** |
| Ação | **K** |
| Gamepad | Suporte nativo |

---

## 8. Constantes Globais

### Botões direcionais

| Constante | Descrição |
|---|---|
| `UP` | Direcional para cima |
| `DOWN` | Direcional para baixo |
| `LEFT` | Direcional para esquerda |
| `RIGHT` | Direcional para direita |

### Botões de ação

| Constante | Descrição |
|---|---|
| `BTN_Z` | Botão Z (ação principal) |
| `BTN_Q` | Botão Q |
| `BTN_E` | Botão E |
| `BTN_F` | Botão F |
| `BTN_G` | Botão G |

> ⚠️ **Atenção:** o Lupinho **não** expõe a constante `BTN_X` como algumas documentações antigas sugerem. Use as constantes acima.

---

## 9. Utilitários

### `ui.log(message)`

Imprime uma mensagem no console do navegador (útil para depuração).

```lua
ui.log("Player X: " .. player.x)
```

---

### `ui.mid(a, b, c)`

Retorna o **valor do meio** entre três números. Muito útil para limitar (clamp) valores.

```lua
-- Mantém x entre 0 e 480
player.x = ui.mid(0, player.x, 480)
```

---

## 10. Exemplo Completo

```lua
-- ==========================================
-- PALETA (BGR555, índices 0–255)
-- ==========================================
Palette = {
    0x0000, 0x1516, 0x25B4, 0x20A6, 0x1DFD, 0x46FE, 0x7FFF, 0x2532
}

-- Registrar paleta (necessário uma vez)
for i = 1, #Palette do
    ui.palset(i - 1, Palette[i])
end

-- ==========================================
-- VARIÁVEIS DO JOGO (executado na carga)
-- ==========================================
x = 200
t = 0

-- ==========================================
-- LOOP PRINCIPAL
-- ==========================================
function update()
    t = t + 0.05
    y = math.sin(t) * 25

    -- Desenho
    ui.print("Bem-vindo ao Lupi!", 280, 180 + math.floor(y))
    ui.rect(50, 50, 130, 130, 1)
    ui.circfill(200, 100, 20, 3)
    ui.trisfill(20, 250, 100, 250, 55, 350, 4)

    -- Input
    if ui.btnp(BTN_Z) then
        ui.log("Botão Z pressionado!")
    end

    if ui.btn(LEFT)  then x = x - 2 end
    if ui.btn(RIGHT) then x = x + 2 end
end
```

---

## 11. Compilando e Testando

### Pré-requisitos

- **Emscripten SDK** instalado e ativado
- **Node.js** (para servir os arquivos)
- **Git**

### Instalação do Emscripten

```bash
git clone https://github.com/emscripten-core/emsdk.git ~/emsdk
cd ~/emsdk
./emsdk install latest
./emsdk activate latest
source ./emsdk_env.sh
```

Confirme:

```bash
emcc --version
```

### Clonando o Lupinho

```bash
git clone https://github.com/lupi-org-br/lupinho.git
cd lupinho
```

### Compilando

```bash
cd src

# Build de desenvolvimento (com contador de FPS)
make web

# Build de produção (otimizado)
make production
```

Os arquivos de saída ficam em `dist/`:

- `game.html`
- `game.js`
- `game.wasm`
- `game.data` (se houver assets)

### Servindo localmente

**Com `npx serve`:**

```bash
cd src
npx serve ../dist
```

Abra o endereço mostrado (geralmente `http://localhost:3000`).

**Com XAMPP** (se seu Lupinho estiver em `/opt/lampp/htdocs/`):

```bash
sudo /opt/lampp/lampp start
```

Abra `http://localhost/lupinho/dist/game.html`.

### Limpeza

```bash
make clean
```

---

## 12. Migrando do Pico-8

Embora inspirado no Pico-8, o Lupi tem diferenças importantes:

### 12.1 Sprites e mapas

No Pico-8, sprites são globais. No Lupi, você passa a **tabela** de sprites:

- **Pico-8:** `spr(1, 10, 10)`
- **Lupi:** `ui.spr(meu_sprite_sheet, 10, 10)`

### 12.2 Cores obrigatórias

Muitas funções gráficas no Pico-8 têm cor opcional. No Lupi, a cor é **obrigatória**:

- **Pico-8:** `rectfill(0, 0, 10, 10)`
- **Lupi:** `ui.rectfill(0, 0, 10, 10, 7)`

### 12.3 Resolução

- **Pico-8:** 128 × 128
- **Lupi:** 480 × 270 (widescreen)

### 12.4 Namespace `ui`

Todas as funções gráficas estão no namespace `ui.*`.

### 12.5 Loop unificado

No Pico-8 há `_init()`, `_update()` e `_draw()`. No Lupi, só existe `update()`.

**Pico-8:**
```lua
function _init() x = 64 end
function _update() if btn(0) then x = x - 1 end end
function _draw() cls(); spr(1, x, 64) end
```

**Lupi:**
```lua
x = 240  -- init no escopo do arquivo

function update()
    if ui.btn(LEFT) then x = x - 1 end
    ui.cls(1)
    ui.spr(sprite, x, 135)
end
```

### 12.6 Paleta personalizável

No Pico-8, a paleta é fixa (16 cores). No Lupi, você define até **256 cores** em **BGR555** e deve registrá-las **a cada frame**.

### 12.7 Tabela de equivalência

| Pico-8 | Lupi | Observação |
|---|---|---|
| `spr(n, x, y)` | `ui.spr(sheet, x, y)` | Requer tabela de sprites |
| `map(...)` | `ui.map(layer, cam_x, cam_y)` | Requer objeto de mapa |
| `print(s, x, y, c)` | `ui.print(s, x, y, c)` | Similar |
| `btn(i)` | `ui.btn(i)` | Mesma funcionalidade |
| `btnp(i)` | `ui.btnp(i)` | Mesma funcionalidade |
| `cls(c)` | `ui.cls(c)` | Mesma funcionalidade |
| `line(...)` | `ui.line(...)` | Similar |
| `circfill(...)` | `ui.circfill(...)` | Similar |
| `rectfill(...)` | `ui.rectfill(...)` | Cor obrigatória |

### 12.8 Recursos novos

- **Sistema de layout** — em desenvolvimento
- **Sistema de arquivos** — o Lupi real tem acesso a arquivos via cartão SD
- **Simulador web** — rode no navegador sem hardware

---

## Recursos Adicionais

- **Repositório oficial:** https://github.com/lupi-org-br/lupinho
- **Jogo demo:** "caio-pernocas" (A/W/S/D + K)
- **Versão atual:** 1.2.0
- **Licença:** MIT

---

**Fim da documentação.**

*Baseada no repositório oficial `lupi-org-br/lupinho`. Sujeita a mudanças — sempre consulte o código-fonte para detalhes mais recentes.*
