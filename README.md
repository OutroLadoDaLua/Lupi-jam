# Documentação da API do Lupi

**Versão:** Revisada com base no repositório oficial, no simulador Lupinho e no hardware real.
**Última atualização:** Outubro de 2026

---

## Índice

1. [Introdução](#1-introdução)
2. [Especificações Técnicas](#2-especificações-técnicas)
3. [Sistema de Cores](#3-sistema-de-cores)
4. [Ciclo Principal](#4-ciclo-principal)
5. [API Gráfica](#5-api-gráfica)
6. [API de Entrada](#6-api-de-entrada)
7. [Constantes Globais](#7-constantes-globais)
8. [Utilitários](#8-utilitários)
9. [Áudio](#9-áudio)
10. [Formato de Pacote (.lupi)](#10-formato-de-pacote-lupi)
11. [Exemplo Completo](#11-exemplo-completo)
12. [Distribuição no Console](#12-distribuição-no-console)
13. [Migrando do Pico-8](#13-migrando-do-pico-8)

---

## 1. Introdução

O **Lupi** é um console de jogos brasileiro que roda um motor 2D próprio escrito em **Lua 5.4**. Os jogos são empacotados num formato simples (`.lupi`) e executados tanto no **console real** quanto no **simulador web (Lupinho)**.

Esta documentação cobre a API disponível para desenvolver seus jogos.

---

## 2. Especificações Técnicas

| Propriedade | Valor |
|---|---|
| Resolução | 480 × 270 pixels (16:9 widescreen) |
| Cores | Paleta indexada com 256 cores |
| Formato de cor | 16 bits (5 bits por canal) — ver [seção 3](#3-sistema-de-cores) |
| Frame rate | 60 FPS |
| Linguagem de script | Lua 5.4 |
| Hardware | ESP32-S3 n16r8 @ 240 MHz + RP2350 OC @ 345 MHz |
| Armazenamento | Cartão SD (FAT32) |
| Biblioteca gráfica | Raylib (no simulador) |

---

## 3. Sistema de Cores

O Lupi usa um formato de **16 bits**, aproveitando **15 bits** (5 por canal). O bit mais significativo é ignorado.

### ⚠️ Atenção — BGR555 vs RGB555

Existe **divergência** entre a documentação antiga e o código real:

- **Documentação antiga:** afirmava **RGB555**.
- **Simulador Lupinho:** usa **BGR555** (Big Endian).
- **Console real:** provavelmente **BGR555**, mas **isso não está 100% confirmado** — o repositório tem um commit chamado `Revert "fix-bgr-color-extraction"`, o que indica idas e voltas.

**Recomendação prática:** isole a conversão numa função e teste no hardware com uma cor pura.

### Formatos possíveis

**BGR555 (usado pelo simulador):**
```
0BBBBBGGGGGRRRRR
```

**RGB555 (documentação antiga):**
```
0RRRRRGGGGGBBBBB
```

### Função de conversão segura

```lua
-- Palette.lua
function Palette.hex(rgb)
    local r = math.floor(rgb / 0x10000) % 0x100
    local g = math.floor(rgb / 0x100) % 0x100
    local b = rgb % 0x100

    -- SIMULADOR — BGR555
    return (math.floor(b / 8) << 10) | (math.floor(g / 8) << 5) | math.floor(r / 8)

    -- CONSOLE — se as cores saírem invertidas (vermelho↔azul),
    -- troque pela linha abaixo:
    -- return (math.floor(r / 8) << 10) | (math.floor(g / 8) << 5) | math.floor(b / 8)
end
```

### Como identificar no seu hardware

Exiba uma cor pura conhecida:

```lua
ui.cls(Palette.hex(0xFF0000))  -- vermelho puro
```

- Se aparecer **vermelho** → formato atual está correto.
- Se aparecer **azul** → canais invertidos, troque a fórmula.

### Registro da paleta (obrigatório todo frame)

A paleta deve ser registrada **a cada frame** dentro do `update()`:

```lua
for i = 1, #Palette do
    ui.palset(i - 1, Palette[i])
end
```

Esquecer isso é a causa mais comum de cores erradas.

---

## 4. Ciclo Principal

### `update()`

Chamada **60 vezes por segundo**. Toda a lógica do jogo — input, atualização e desenho — acontece aqui.

```lua
-- Código fora de update() roda uma vez na carga (inicialização)
player = { x = 240, y = 135 }

function update()
    -- 1. Registrar paleta (obrigatório)
    -- 2. Ler input
    -- 3. Atualizar lógica
    -- 4. Desenhar
end
```

> ℹ️ **Não existem** `_init()`, `_update()` ou `_draw()` separados como no Pico-8. Use o escopo do arquivo para inicialização.

### Padrão comum — delegar para uma função `loop()`

```lua
-- game.lua
require "main"

Frame = 0

function update()
    Frame = Frame + 1
    loop(Frame)
end
```

---

## 5. API Gráfica

Todas as funções estão no namespace `ui.*` e usam **índices de paleta** (0–255) para cores.

### 5.1 Tela

#### `ui.cls(color)`
Limpa a tela com a cor da paleta especificada.

```lua
ui.cls(0)   -- preto
ui.cls(12)  -- azul
```

#### `ui.camera(x, y)`
Define o deslocamento da câmera. Sem argumentos, reseta para (0, 0).

```lua
ui.camera(player.x - 240, player.y - 135)
ui.camera()  -- resetar
```

#### `ui.clip(x, y, w, h)`
Define a região de recorte. Sem argumentos, reseta.

```lua
ui.clip(0, 0, 480, 270)
ui.clip()  -- resetar
```

#### `ui.fillp(b1, b2, ...)`
Define padrão de preenchimento 8×8 (1 byte por linha). Sem argumentos, volta ao sólido.

```lua
ui.fillp(0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55)
ui.rectfill(0, 0, 100, 100, 7)
ui.fillp()  -- sólido
```

---

### 5.2 Primitivas

#### `ui.rect(x1, y1, x2, y2, color)`
Retângulo (contorno).

```lua
ui.rect(50, 50, 130, 130, 1)
```

#### `ui.rectfill(x1, y1, x2, y2, color)`
Retângulo preenchido.

```lua
ui.rectfill(50, 50, 100, 100, 8)
```

#### `ui.draw_rect(x, y, w, h, filled, color)`
Retângulo usando **largura/altura** em vez de coordenadas.

| Parâmetro | Descrição |
|---|---|
| `x, y` | Canto superior esquerdo |
| `w, h` | Largura e altura |
| `filled` | `true` = preenchido, `false` = contorno |
| `color` | Índice da paleta |

```lua
ui.draw_rect(50, 50, 80, 50, true, 8)
ui.draw_rect(50, 50, 80, 50, false, 7)
```

#### `ui.circfill(x, y, radius, color)`
Círculo preenchido.

```lua
ui.circfill(200, 100, 20, 3)
```

#### `ui.draw_circle(cx, cy, r, filled, color, border, border_color)`
Círculo com borda opcional.

| Parâmetro | Descrição |
|---|---|
| `cx, cy` | Centro |
| `r` | Raio |
| `filled` | `true` = preenchido, `false` = contorno |
| `color` | Cor de preenchimento |
| `border` | Espessura da borda (opcional) |
| `border_color` | Cor da borda (opcional) |

```lua
ui.draw_circle(240, 135, 30, true, 11, 2, 7)
```

#### `ui.trisfill(x1, y1, x2, y2, x3, y3, color)`
Triângulo preenchido.

```lua
ui.trisfill(20, 250, 100, 250, 55, 350, 4)
```

#### `ui.line(x1, y1, x2, y2, color)`
Linha entre dois pontos.

```lua
ui.line(0, 0, 480, 270, 6)
```

---

### 5.3 Texto

#### `ui.print(text, x, y, color)`
Desenha texto com a fonte bitmap embutida.

| Parâmetro | Descrição |
|---|---|
| `text` | String |
| `x, y` | Posição |
| `color` | Índice da paleta |

```lua
ui.print("Oi, Lupi!", 32, 32, Palette.hex(0x73428C))
```

> ⚠️ **Ordem dos argumentos:** texto → x → y → cor. Inverter isso é um erro clássico.

---

### 5.4 Sprites e Tiles

#### `ui.spr(sprite_table, x, y, flipped)`
Desenha um sprite.

| Parâmetro | Descrição |
|---|---|
| `sprite_table` | Tabela de dados do sprite sheet |
| `x, y` | Posição |
| `flipped` | `true` para inverter horizontalmente (opcional) |

```lua
ui.spr(player_sprite, 100, 100)
ui.spr(player_sprite, 100, 100, true)  -- espelhado
```

> ⚠️ **Diferença do Pico-8:** sprites são **referências a tabelas**, não índices numéricos.

#### `ui.tile(tileset_table, tile_index, x, y)`
Desenha um tile específico.

| Parâmetro | Descrição |
|---|---|
| `tileset_table` | Tabela do tileset |
| `tile_index` | Índice do tile |
| `x, y` | Posição |

> 💡 **Flip horizontal:** o **bit 10** do índice inverte o tile. Some `1024` para flipar.

```lua
ui.tile(tileset, 5, 200, 150)         -- normal
ui.tile(tileset, 5 + 1024, 200, 150)  -- espelhado
```

---

### 5.5 Mapas

#### `ui.map(layer_table, cam_x, cam_y)`
Desenha uma camada de tilemap com suporte a câmera.

| Parâmetro | Descrição |
|---|---|
| `layer_table` | Tabela com os dados da camada |
| `cam_x, cam_y` | Offset da câmera |

```lua
local cam_x = 240 - player.x
local cam_y = 135 - player.y
ui.map(mapa_fase_1, cam_x, cam_y)
```

---

### 5.6 Paleta

#### `ui.palset(index, color)`
Define a cor no índice especificado.

| Parâmetro | Descrição |
|---|---|
| `index` | Índice da cor (0–255) |
| `color` | Valor de 16 bits (BGR555 ou RGB555) |

```lua
ui.palset(8, 0x03E0)
```

> ⚠️ **Deve ser chamado a cada frame** para todas as cores usadas.

---

## 6. API de Entrada

### 6.1 Controle e Teclado

#### `ui.btn(button, pad)`
Verifica se um botão está sendo mantido pressionado. Funciona com **gamepad e teclado**.

| Parâmetro | Descrição |
|---|---|
| `button` | Constante (`UP`, `DOWN`, `LEFT`, `RIGHT`, `BTN_Z`, `BTN_Q`, `BTN_E`, `BTN_F`, `BTN_G`) |
| `pad` | Índice do jogador (opcional, padrão 0) |

```lua
if ui.btn(LEFT)  then player.x = player.x - 2 end
if ui.btn(RIGHT) then player.x = player.x + 2 end
if ui.btn(BTN_Z, 1) then jump(1) end  -- segundo jogador
```

#### `ui.btnp(button, pad)`
Verifica se o botão foi **pressionado neste frame** (borda). Útil para ações que não devem repetir.

```lua
if ui.btnp(BTN_Z) then
    ui.log("Botão Z pressionado!")
    shoot()
end
```

### 6.2 Teclas padrão no simulador

| Ação | Tecla |
|---|---|
| Mover | **A / W / S / D** |
| Ação | **K** |
| Gamepad | Suporte nativo |

---

## 7. Constantes Globais

### Direcionais

| Constante | Descrição |
|---|---|
| `UP` | Cima |
| `DOWN` | Baixo |
| `LEFT` | Esquerda |
| `RIGHT` | Direita |

### Ação

| Constante | Descrição |
|---|---|
| `BTN_Z` | Ação principal |
| `BTN_Q` | Botão Q |
| `BTN_E` | Botão E |
| `BTN_F` | Botão F |
| `BTN_G` | Botão G |

> ⚠️ **Atenção:** a constante `BTN_X` **não existe** no Lupi. Use apenas as listadas acima.

---

## 8. Utilitários

#### `ui.log(message)`
Imprime mensagem no console (útil para depuração).

```lua
ui.log("Player X: " .. player.x)
```

#### `ui.mid(a, b, c)`
Retorna o valor do meio entre três números. Perfeito para clamp.

```lua
-- Mantém x entre 0 e 480
player.x = ui.mid(0, player.x, 480)
```

---

## 9. Áudio

### `sfx.music(nome)`
Toca música (arquivo WAV). Use `-1` para parar.

```lua
sfx.music("background")
sfx.music(-1)
```

### `sfx.fx(sample, note, [pan])`
Toca efeito sonoro.

| Parâmetro | Descrição |
|---|---|
| `sample` | ID do sample |
| `note` | Nota MIDI (0–127) |
| `pan` | Panorama (0.0–1.0, padrão 0.5) |

```lua
sfx.fx(0, 60)         -- C4, centro
sfx.fx(3, 72, 0.8)    -- C5, direita
```

### `sfx.volume(vol)`
Volume global (0.0–1.0).

```lua
sfx.volume(0.5)
```

---

## 10. Formato de Pacote (.lupi)

O console **e** o simulador carregam jogos no formato **`.lupi`**, que é um **arquivo ZIP** com uma estrutura específica.

### Estrutura obrigatória

```
meu-jogo.lupi (ZIP)
├── game.lua           ← obrigatório, na raiz
├── main.lua
├── Palette.lua
├── Sprites.lua
├── lupi.yaml          ← metadados (recomendado)
├── img/               ← sprites (opcional)
├── map/               ← tilemaps (opcional)
└── audio/             ← arquivos WAV (opcional)
```

> ⚠️ **Sem pasta raiz dentro do ZIP.** Se os arquivos ficarem em `primeiro-jogo-main/game.lua` dentro do zip, o console não acha. Rode o `zip` **de dentro** da pasta do jogo.

### Metadados — `lupi.yaml`

```yaml
name: Meu jogo
public: true
version: 1.2
```

### Empacotando

```bash
cd /caminho/do/seu-jogo

zip -r ../meu-jogo.lupi \
    game.lua \
    main.lua \
    Palette.lua \
    Sprites.lua \
    lupi.yaml

# Confirmar estrutura (sem pasta raiz):
unzip -l ../meu-jogo.lupi
```

Saída esperada:

```
  Length      Date    Time    Name
---------  ---------- -----   ----
      ...   ...         game.lua
      ...   ...         main.lua
      ...   ...         Palette.lua
      ...   ...         Sprites.lua
      ...   ...         lupi.yaml
```

---

## 11. Exemplo Completo

### `game.lua` — ponto de entrada

```lua
require "main"

Frame = 0

function update()
    Frame = Frame + 1
    loop(Frame)
end
```

### `main.lua` — lógica principal

```lua
require "Palette"
require "Sprites"

function loop(frame)
    -- 1. Registrar paleta (obrigatório todo frame)
    for i = 1, #Palette do
        ui.palset(i - 1, Palette[i])
    end

    -- 2. Resetar clip e câmera
    ui.clip(0, 0, 480, 270)
    ui.camera(0, 0)

    -- 3. Limpar tela
    ui.cls(1)

    -- 4. Desenhar
    ui.print("Oi, Lupi! Frame: " .. frame, 32, 32, Palette.hex(0x73428C))
    ui.rectfill(50, 50, 100, 100, 8)
    ui.circfill(240, 135, 8, 7)

    -- 5. Input
    if ui.btnp(BTN_Z) then
        ui.log("Botão Z pressionado!")
    end
end
```

### `Palette.lua`

```lua
Palette = {
    0x0000, 0x1516, 0x25B4, 0x20A6, 0x1DFD, 0x46FE, 0x7FFF, 0x2532,
    -- adicione até o índice necessário (máx. 256)
}

function Palette.hex(rgb)
    local r = math.floor(rgb / 0x10000) % 0x100
    local g = math.floor(rgb / 0x100) % 0x100
    local b = rgb % 0x100
    return (math.floor(b / 8) << 10) | (math.floor(g / 8) << 5) | math.floor(r / 8)
end
```

### `Sprites.lua`

```lua
-- Vazio por enquanto
```

### `lupi.yaml`

```yaml
name: Primeiro Jogo
public: true
version: 1.2
```

---

## 12. Distribuição no Console

### 12.1 Preparar o cartão SD

1. Formatar o cartão como **FAT32**.
2. Copiar o arquivo `.lupi` para o cartão.
   - O caminho exato depende do firmware (provavelmente a **raiz** ou uma pasta `/games/`).
   - Se o console tiver menu, ele deve indicar a pasta esperada.

### 12.2 Fluxo recomendado

```
1. Empacotar o jogo:      zip -r meu-jogo.lupi game.lua main.lua ...
2. Confirmar estrutura:   unzip -l meu-jogo.lupi
3. Copiar para o SD:      cp meu-jogo.lupi /media/$USER/SDCARD/
4. Ejetar o cartão com segurança.
5. Inserir no console e ligar.
```

### 12.3 Depuração

O ESP32-S3 expõe uma **porta serial USB**. Conecte o console ao computador e monitore:

```bash
# Identifique a porta
ls /dev/ttyUSB* /dev/ttyACM*

# Monitore (ajuste a porta e o baud)
screen /dev/ttyUSB0 115200
# ou
minicom -D /dev/ttyUSB0 -b 115200
```

Erros de sintaxe Lua ou arquivos não encontrados geralmente aparecem lá.

### 12.4 Checklist antes de gravar

- [ ] `Palette.lua` e `Sprites.lua` existem (ou não são referenciados)
- [ ] `ui.print` com argumentos na ordem `(texto, x, y, cor)`
- [ ] ZIP tem `game.lua` **na raiz** (verificado com `unzip -l`)
- [ ] `lupi.yaml` preenchido com `name:` e `version:`
- [ ] Cor pura testada para confirmar BGR555 vs RGB555
- [ ] Áudios em WAV dentro do pacote
- [ ] SD formatado em FAT32

---

## 13. Migrando do Pico-8

Embora inspirado no Pico-8, o Lupi tem diferenças importantes:

### 13.1 Sprites são tabelas

- **Pico-8:** `spr(1, 10, 10)`
- **Lupi:** `ui.spr(meu_sprite_sheet, 10, 10)`

### 13.2 Cor é obrigatória

- **Pico-8:** `rectfill(0, 0, 10, 10)` (usa "pen color")
- **Lupi:** `ui.rectfill(0, 0, 10, 10, 7)` (cor explícita)

### 13.3 Resolução

- **Pico-8:** 128 × 128
- **Lupi:** 480 × 270

### 13.4 Namespace `ui.*`

Todas as funções gráficas ficam em `ui.*`.

### 13.5 Loop unificado

- **Pico-8:** `_init()` + `_update()` + `_draw()`
- **Lupi:** só `update()`. Inicialização no escopo do arquivo.

### 13.6 Paleta personalizável

- **Pico-8:** 16 cores fixas
- **Lupi:** até **256 cores** definidas pelo usuário, registradas **todo frame**

### 13.7 Tabela de equivalência

| Pico-8 | Lupi | Observação |
|---|---|---|
| `spr(n, x, y)` | `ui.spr(sheet, x, y)` | Requer tabela de sprites |
| `map(...)` | `ui.map(layer, cx, cy)` | Requer objeto de mapa |
| `print(s, x, y, c)` | `ui.print(s, x, y, c)` | Similar |
| `btn(i)` | `ui.btn(i)` | Igual |
| `btnp(i)` | `ui.btnp(i)` | Igual |
| `cls(c)` | `ui.cls(c)` | Igual |
| `line(...)` | `ui.line(...)` | Similar |
| `circfill(...)` | `ui.circfill(...)` | Similar |
| `rectfill(...)` | `ui.rectfill(...)` | Cor obrigatória |

### 13.8 Recursos novos

- **Pacote `.lupi`** — distribuição em ZIP com metadados
- **Sistema de arquivos via cartão SD** no console real
- **Simulador web** — Lupinho, para desenvolvimento rápido no navegador

---

## Recursos Adicionais

- **Repositório do simulador:** `https://github.com/lupi-org-br/lupinho`
- **Jogo demo:** "caio-pernocas" (A/W/S/D + K)
- **Licença:** MIT
- **Versão do simulador:** 1.2.0

---

**Fim da documentação.**

*Baseada no repositório oficial, no simulador Lupinho e nas observações do hardware. Como o projeto está em desenvolvimento ativo, sempre consulte o código-fonte para detalhes mais recentes.*
