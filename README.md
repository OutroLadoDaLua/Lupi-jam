# Lupi Game API — Complete Documentation

**Version:** Provisional — for study purposes. Changes occur frequently.
**Last updated:** 26/03/2026 2:48

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Technical Specifications](#2-technical-specifications)
3. [Color System (RGB555)](#3-color-system-rgb555)
4. [Documentation Structure](#4-documentation-structure)
5. [Quick Example](#5-quick-example)
6. [Graphics API](#6-graphics-api)
7. [System & Input API](#7-system--input-api)
8. [Audio API](#8-audio-api)
9. [Layout (UI) System](#9-layout-ui-system)
10. [Global Constants](#10-global-constants)
11. [Migrating from Pico-8](#11-migrating-from-pico-8)
12. [AGENTS.md Reference](#12-agentsmd-reference)

---

## 1. Introduction

Welcome to **Lupi**.

The Lupi console contains its own **2D game engine, written in Lua**, designed to make game development straightforward.

This documentation covers the API available for creating your games and applications.

---

## 2. Technical Specifications

| Property | Value |
|---|---|
| Resolution | 480 × 270 pixels (Widescreen 16:9) |
| Colors | Indexed palette system with 256 colors |
| Hardware | ESP32-S3 n16r8 @ 240 MHz + RP2350 OC @ 345 MHz |
| Frame rate | 60 FPS target |
| Main callback | `update(frame)` — called 60 times per second |
| Color format | RGB555 (16-bit, MSB ignored) |

---

## 3. Color System (RGB555)

Lupi uses a **16-bit color format**, where only 15 bits are used (**RGB555**). The most significant bit is ignored.

**Binary format:** `0RRRRRGGGGGBBBBB`

- **R (Red):** 5 bits (0–31)
- **G (Green):** 5 bits (0–31)
- **B (Blue):** 5 bits (0–31)

**Examples:**
- White: `0x7FFF` (32767)
- Pure Red: `0x7C00`
- Pure Blue: `0x001F`

### Color Converter

Select a color to get the hexadecimal value compatible with Lupi (RGB555).

- R: [slider 0–31] → Hex Lupi (0x...)
- G: [slider 0–31] → Decimal
- B: [slider 0–31] → Binary (0bb...)

---

## 4. Documentation Structure

- **Graphics:** Drawing primitives, sprites, and maps.
- **System & Input:** Controller input, mouse, audio, and utility functions.
- **Layout (UI):** Advanced responsive UI creation system.
- **Migrating from Pico-8:** Quick guide for those coming from Pico-8.

---

## 5. Quick Example

```lua
-- Color palette (RGB555) - indices 0 to 99
Palette = {
    0x0000, 0x0000, 0x0022, 0x02FF, 0x6FF7, 0x7EE7, 0x0001, 0x5FF7,
    0x2D00, 0x01F5, 0x3F7F, 0x2108, 0x5B5E, 0x4620, 0x00CA, 0x3DEF,
    -- ... continue with more colors up to index 99
}

-- Initialization (runs once at load)
player = { x = 240, y = 135 }

function update(frame)
  -- Register color palette (required every frame)
  for i = 1, #Palette do
    ui.palset(i - 1, Palette[i])
  end

  -- Clear screen with dark blue (index 1)
  ui.cls(1)

  -- Draw text and rectangle
  ui.print("Ola Mundo! Frame: " .. frame, 120, 130, 7)
  ui.rectfill(50, 50, 100, 100, 8)

  -- Player movement
  if ui.btn(LEFT) then player.x = player.x - 2 end
  if ui.btn(RIGHT) then player.x = player.x + 2 end

  -- Draw the player
  ui.circfill(player.x, player.y, 8, 7)
end
```

---

## 6. Graphics API

Functions for drawing geometric shapes, sprites, and maps. All graphics functions are available globally or through the `ui` table.

### 6.1 Primitives

---

#### `cls(col)`

Clears the screen and resets the clipping rectangle.

| Parameter | Type | Description |
|---|---|---|
| `col` | number | Color index (0–255) to fill the screen. |

```lua
-- Clear screen with black
ui.cls(0)

-- Clear screen with blue
ui.cls(12)
```

---

#### `rect(x0, y0, x1, y1, col)`

Draws a rectangle (outline only).

| Parameter | Type | Description |
|---|---|---|
| `x0` | number | X coordinate of top-left corner. |
| `y0` | number | Y coordinate of top-left corner. |
| `x1` | number | X coordinate of bottom-right corner. |
| `y1` | number | Y coordinate of bottom-right corner. |
| `col` | number | Color index (0–255). |

```lua
-- Draw a white rectangle outline
ui.rect(10, 10, 100, 50, 7)
```

---

#### `rectfill(x0, y0, x1, y1, col)`

Draws a filled rectangle.

| Parameter | Type | Description |
|---|---|---|
| `x0` | number | X coordinate of top-left corner. |
| `y0` | number | Y coordinate of top-left corner. |
| `x1` | number | X coordinate of bottom-right corner. |
| `y1` | number | Y coordinate of bottom-right corner. |
| `col` | number | Color index (0–255). |

```lua
-- Draw a solid red square
ui.rectfill(50, 50, 80, 80, 8)
```

---

#### `circ(x, y, r, col)`

Draws a circle (outline only).

| Parameter | Type | Description |
|---|---|---|
| `x` | number | X coordinate of center. |
| `y` | number | Y coordinate of center. |
| `r` | number | Circle radius. |
| `col` | number | Color index (0–255). |

```lua
-- Empty green circle at screen center
ui.circ(240, 135, 30, 11)
```

---

#### `circfill(x, y, r, col)`

Draws a filled circle.

| Parameter | Type | Description |
|---|---|---|
| `x` | number | X coordinate of center. |
| `y` | number | Y coordinate of center. |
| `r` | number | Circle radius. |
| `col` | number | Color index (0–255). |

```lua
-- Yellow full moon
ui.circfill(400, 50, 20, 10)
```

---

#### `trisfill(x1, y1, x2, y2, x3, y3, col)`

Draws a filled triangle.

| Parameter | Type | Description |
|---|---|---|
| `x1, y1` | number | Coordinates of first vertex. |
| `x2, y2` | number | Coordinates of second vertex. |
| `x3, y3` | number | Coordinates of third vertex. |
| `col` | number | Color index (0–255). |

```lua
-- Orange triangle
ui.trisfill(100, 100, 120, 60, 140, 100, 9)
```

---

#### `line(x0, y0, x1, y1, col)`

Draws a line between two points.

| Parameter | Type | Description |
|---|---|---|
| `x0, y0` | number | Starting point. |
| `x1, y1` | number | Ending point. |
| `col` | number | Color index (0–255). |

```lua
-- Gray diagonal line
ui.line(0, 0, 480, 270, 6)
```

---

#### `grid(x, y, cell_w, cell_h, data)`

Draws a pixel grid based on a data table.

| Parameter | Type | Description |
|---|---|---|
| `x, y` | number | Starting position of the grid. |
| `cell_w` | number | Width of each cell. |
| `cell_h` | number | Height of each cell. |
| `data` | table | Table of tables containing color indices. |

```lua
local grade = {
    {1, 2, 1},
    {2, 1, 2},
    {1, 2, 1}
}
-- Draws a 3x3 grid where each cell is 10x10 pixels
ui.grid(50, 50, 10, 10, grade)
```

---

### 6.2 Sprites and Maps

> **Important Note:** Unlike Pico-8, sprite functions in Lupi work with **sprite references** (userdata/table) loaded via the asset system, **not numeric indices**.

---

#### `spr(sprite_ref, x, y, [flip_x], [flip_y])`

Draws a sprite (tile 0) from a sprite reference.

| Parameter | Type | Description |
|---|---|---|
| `sprite_ref` | userdata/table | Reference to sprite data (usually loaded via asset system). |
| `x, y` | number | Screen position. |
| `flip_x` | boolean | Flip horizontally (optional, default `false`). |
| `flip_y` | boolean | Flip vertically (optional, default `false`). |

```lua
-- Draw the player at (100, 100)
ui.spr(player_sprite, 100, 100)

-- Draw the player horizontally flipped (facing left)
ui.spr(player_sprite, 100, 100, true, false)
```

---

#### `tile(sprite_ref, tile_id, x, y, [flip_x], [flip_y])`

Draws a specific tile from a sprite reference.

| Parameter | Type | Description |
|---|---|---|
| `sprite_ref` | userdata/table | Reference to sprite data. |
| `tile_id` | number | Index of the tile to draw (0–1023). |
| `x, y` | number | Screen position. |
| `flip_x` | boolean | Flip horizontally (optional, default `false`). |
| `flip_y` | boolean | Flip vertically (optional, default `false`). |

```lua
-- Draw tile number 5 from the enemy sheet
ui.tile(enemy_sprites, 5, 200, 150)
```

---

#### `map(map_data, cam_x, cam_y)`

Draws a complete map on screen, with camera support.

| Parameter | Type | Description |
|---|---|---|
| `map_data` | table | Table containing map data and metadata (`lupi_metadata`). |
| `cam_x` | number | Camera X position (offset). |
| `cam_y` | number | Camera Y position (offset). |

The `map_data` table must contain string keys pointing to tile data tables, and a special key `lupi_metadata` with `width`, `height`, and `tile_size`.

```lua
-- Draw the map with the camera following the player
-- player.x and player.y are the player's world coordinates
local cam_x = 240 - player.x
local cam_y = 135 - player.y

ui.map(mapa_fase_1, cam_x, cam_y)
```

---

## 7. System & Input API

Functions for handling user input (controller, mouse, keyboard), audio, and system settings.

### 7.1 Input

---

#### `btn(id, [player])`

Checks if a button is being held down.

| Parameter | Type | Description |
|---|---|---|
| `id` | number | Button ID (constants: `LEFT`, `RIGHT`, `UP`, `DOWN`, `BTN_Z`, `BTN_X`, `BTN_F`, `BTN_G`, `BTN_Q`, `BTN_E`). |
| `player` | number | Player index (0–2). Optional, default 0. |

**Returns:** `false` if not pressed, or `number` (pressure 0–255) if pressed.

```lua
if ui.btn(LEFT) then
    player.x = player.x - 1
end

-- Checking second player's button
if ui.btn(BTN_Z, 1) then
    jump()
end
```

---

#### `btnp(id, [player])`

Checks if a button was pressed **this frame** (edge detection — transition from not pressed to pressed).

| Parameter | Type | Description |
|---|---|---|
| `id` | number | Button ID (see constants in `ui.btn`). |
| `player` | number | Player index (optional). |

**Returns:** `false` or `number` (pressure 0–255).

```lua
-- Only fires the shot once per click
if ui.btnp(BTN_X) then
    shoot()
end
```

---

#### `mouse()`

Gets the current mouse state.

**Returns:** 5 values: `x`, `y`, `buttons_bitfield`, `wheel_x`, `wheel_y`.

- `x`, `y`: Cursor position in pixels.
- `buttons_bitfield`: Button bits (bit 0 = left, bit 1 = right).
- `wheel_x`, `wheel_y`: Wheel values (currently unsupported, return 0).

```lua
local mx, my, mbtn, wx, wy = ui.mouse()

-- If left button (bit 0) is pressed
if (mbtn & 1) ~= 0 then
    -- Draw a dot where the mouse is
    ui.rectfill(mx, my, mx+1, my+1, 7)
end
```

---

#### `peektext()`

Peeks at the next character from the keyboard buffer **without removing it**.

**Returns:** `string` (character) or `nil`.

```lua
local char = ui.peektext()
if char then
    -- There is something to read
end
```

---

#### `readtext()`

Reads and removes the next character from the keyboard buffer.

**Returns:** `string` (character) or `nil`.

```lua
local char = ui.readtext()
if char then
    input_buffer = input_buffer .. char
end
```

---

### 7.2 Text

---

#### `print(str, x, y, col)`

Draws a string on screen.

| Parameter | Type | Description |
|---|---|---|
| `str` | string | Text to draw. |
| `x, y` | number | Screen position. |
| `col` | number | Color index. |

```lua
ui.print("GAME OVER", 180, 100, 8)  -- Red
ui.print("Score: " .. score, 10, 10, 7)  -- White
```

---

### 7.3 Configuration & System

---

#### `palset(index, color)`

Changes a color in the current palette.

| Parameter | Type | Description |
|---|---|---|
| `index` | number | Color index to change (0–255). |
| `color` | number | New color value (RGB555). |

```lua
-- Change color 8 (default red) to a custom green
ui.palset(8, 0x07E0)
```

> ⚠️ **Critical:** The palette must be registered **every frame** in your `update()` function.

---

#### `clip(x, y, w, h)`

Sets the clipping region for drawing. Only pixels inside this region will be drawn.

```lua
-- Restrict drawing to a 100x100 window at the center
ui.clip(190, 85, 100, 100)
ui.circfill(240, 135, 80, 7)  -- Will be clipped
ui.clip()  -- Reset clip (no arguments resets)
```

---

#### `camera(x, y)`

Sets the camera offset for all subsequent drawing operations.

```lua
ui.camera(player.x - 240, player.y - 135)
-- Everything drawn now will be offset
ui.spr(spr_inimigo, enemy.x, enemy.y)
ui.camera()  -- Reset camera to (0,0)
```

---

#### `fillp([b0, b1, b2, b3, b4, b5, b6, b7])`

Sets the fill pattern for shapes. Call without arguments to reset to solid.

| Parameter | Type | Description |
|---|---|---|
| `b0`–`b7` | number (optional) | 8 bytes (0–255 each) defining the 8x8 pattern. |

```lua
-- Define a checkerboard pattern (8 bytes)
ui.fillp(0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55)
ui.rectfill(0, 0, 100, 100, 7)
ui.fillp()  -- Reset to solid
```

---

#### `stat(option)`

Returns system statistics.

- `0`: Memory usage (bytes).
- `1`: CPU usage.
- `7`: Current FPS.

```lua
local fps = ui.stat(7)
ui.print("FPS: " .. fps, 0, 0, 6)
```

---

#### `mid(x, y, z)`

Returns the median value among three numbers. Useful for clamping.

```lua
-- Keeps x between 0 and 100
player.x = ui.mid(0, player.x, 100)
```

---

## 8. Audio API

Functions available in the global `sfx` table.

---

#### `sfx.music(music_name)`

Plays music from a WAV file.

| Parameter | Type | Description |
|---|---|---|
| `music_name` | string | Music file name (e.g., `"level1"`). Use `-1` or empty string to stop. |

```lua
-- Play "background" music
sfx.music("background")

-- Stop music
sfx.music(-1)
```

---

#### `sfx.fx(sample, note, [pan])`

Plays a sound effect (sample).

| Parameter | Type | Description |
|---|---|---|
| `sample` | number | Sample ID. |
| `note` | number | MIDI note (0–127) to play the sample. |
| `pan` | number (optional) | Panning (0.0 = left, 0.5 = center, 1.0 = right). |

```lua
-- Play sample 0 at note 60 (C4), center
sfx.fx(0, 60)

-- Play sample 3 at note 72 (C5), right pan
sfx.fx(3, 72, 0.8)
```

---

#### `sfx.volume(vol)`

Sets the global volume.

| Parameter | Type | Description |
|---|---|---|
| `vol` | number | Volume from 0.0 to 1.0 (0% to 100%). |

```lua
-- Set volume to 50%
sfx.volume(0.5)

-- Mute
sfx.volume(0)
```

---

## 9. Layout (UI) System

Lupi integrates the **Clay layout system**, allowing you to create complex and responsive user interfaces declaratively and efficiently. Instead of calculating X/Y positions manually for each element, you define containers and layout rules.

---

### 9.1 `ui.layout(node)`

Main function that renders a layout tree. Must be called inside `_draw()`.

```lua
ui.layout(
    Box() -- Root node
        .add.child(Text().content("Ola"))
)
```

---

### 9.2 Elements (Nodes)

---

#### `Box()`

A flexible rectangular container, similar to a `<div>` in HTML. It is the fundamental building block for layouts.

It can contain multiple children, have a background color, rounded corners, and control the alignment of its items.

**Example: Centered Container**

```lua
local painel = Box()
    .size.width.set.percentage(0.8)   -- 80% of screen width
    .size.height.set.percentage(0.5)  -- 50% of height
    .color.set(1)                     -- Dark blue background
    .alignment.horizontal.set(ALIGN_CENTER)  -- Center children horizontally
    .alignment.vertical.set(ALIGN_CENTER)    -- Center children vertically
    .corner.set.radius(10)            -- Rounded corners
    .gap.set(5)                       -- 5px gap between each child
    .add.child(Text().content("Titulo"))
    .add.child(Text().content("Subtitulo"))
```

---

#### `Text()`

Element for displaying text. Unlike `ui.print`, this element participates in the layout flow, pushing other elements and respecting alignments.

**Example: Styled Text**

```lua
Text()
    .content("Score: 100")
    .color.set(7)              -- White
    .letter_spacing.set(1)     -- Letter spacing
```

---

#### `Image(sprite_data)`

Element for displaying sprites within the layout. Requires the sprite sheet data table (not just the ID).

**Example: Icon**

```lua
-- Assuming 'spr_player' is your sprite table
Image(spr_player)
    .size.width.set.fixed(16)
    .size.height.set.fixed(16)
    .color.set(0)  -- Transparent background (or color if needed)
```

---

#### `Custom(callback)`

Allows drawing custom graphics (using the standard graphics API) within a reserved space in the layout. The callback receives the position and dimensions calculated by the layout.

**Example: Custom Health Bar**

```lua
local function desenha_hp(x, y, w, h)
    ui.rectfill(x, y, x+w, y+h, 8)        -- Red background
    ui.rectfill(x, y, x+(w*0.5), y+h, 11) -- 50% green
end

Custom(desenha_hp)
    .size.width.set.fixed(100)
    .size.height.set.fixed(10)
```

---

### 9.3 Builder API Reference

This reference lists the chainable methods available for configuring elements.

#### Box, Custom & Image

| Category | Method | Description |
|---|---|---|
| **Size (Width)** | `.size.width.set.fixed(px)` | Fixed width in pixels. |
| | `.size.width.set.percentage(pct)` | Width as percentage (0.0–1.0) of parent. |
| | `.size.width.set.grow()` | Takes up remaining available space. |
| | `.size.width.set.fit()` | Fits to content (children). |
| **Size (Height)** | `.size.height.set.fixed(px)` | Fixed height in pixels. |
| | `.size.height.set.percentage(pct)` | Height as percentage (0.0–1.0) of parent. |
| | `.size.height.set.grow()` | Takes up remaining available space. |
| | `.size.height.set.fit()` | Fits to content. |
| **Spacing** | `.padding.set.all(px)` | Equal internal padding on all sides. |
| | `.padding.set(x, y)` | Horizontal (x) and vertical (y) padding. |
| | `.gap.set(px)` | Space between child elements. |
| **Alignment** | `.alignment.horizontal.set(const)` | `ALIGN_START` (Left), `ALIGN_CENTER`, `ALIGN_END` (Right). |
| | `.alignment.vertical.set(const)` | `ALIGN_START` (Top), `ALIGN_CENTER`, `ALIGN_END` (Bottom). |
| **Direction** | `.set.direction(const)` | `LEFT_TO_RIGHT` (Row) or `TOP_TO_BOTTOM` (Column). |
| **Style** | `.color.set(idx)` | Sets background color (palette index). |
| | `.corner.set.radius(px)` | Corner rounding radius for all corners. |
| | `.corner.set_top_left_radius(px)` | Specific top-left corner radius. |
| | `.corner.set_top_right_radius(px)` | Specific top-right corner radius. |
| | `.corner.set_bottom_left_radius(px)` | Specific bottom-left corner radius. |
| | `.corner.set_bottom_right_radius(px)` | Specific bottom-right corner radius. |
| **Clipping** | `.clip.set_vertical(bool)` | Enable/disable vertical clipping. |
| | `.clip.set_horizontal(bool)` | Enable/disable horizontal clipping. |
| | `.clip.set_child_offset(x, y)` | Offsets children (useful for scroll). |
| **Other** | `.add.child(node)` | Adds a child element. |
| | `.set.visible(bool)` | Defines whether the element is rendered. |

#### Text (Specific Methods)

| Method | Description |
|---|---|
| `.content(string)` | Sets the text to be displayed. |
| `.font.set.id(id)` | Sets the font ID (if multiple fonts exist). |
| `.letter_spacing.set(px)` | Sets extra spacing between letters. |
| `.line_height.set(px)` | Sets line height. |
| `.color.set(idx)` | Sets text color. |

---

## 10. Global Constants

The following constants are available globally:

### Directional Buttons

| Constant | Value | Description |
|---|---|---|
| `LEFT` | 0 | Directional left |
| `RIGHT` | 1 | Directional right |
| `UP` | 2 | Directional up |
| `DOWN` | 3 | Directional down |

### Action Buttons

| Constant | Value | Description |
|---|---|---|
| `BTN_Z` | 4 | Z button (usually B/Y on SNES) |
| `BTN_X` | 5 | X button (usually A/X on SNES) |
| `BTN_F` | 12 | F button (Y on SNES) |
| `BTN_G` | 13 | G button (A on SNES) |
| `BTN_Q` | 14 | Q button (L on SNES) |
| `BTN_E` | 15 | E button (R on SNES) |

### Layout Constants

| Constant | Description |
|---|---|
| `ALIGN_START` | Align to start (left/top) |
| `ALIGN_CENTER` | Align to center |
| `ALIGN_END` | Align to end (right/bottom) |
| `LEFT_TO_RIGHT` | Horizontal layout direction |
| `TOP_TO_BOTTOM` | Vertical layout direction |

---

## 11. Migrating from Pico-8

Although inspired by Pico-8, Lupi has important API differences. Here is a summary to help with the transition.

### 11.1 Main Differences

#### 1. Sprite and Map Arguments

In Pico-8, sprites are global. In Lupi, you must specify which sprite table you want to draw from.

- **Pico-8:** `spr(1, 10, 10)`
- **Lupi:** `ui.spr(meu_sprite_sheet, 10, 10)`

#### 2. Mandatory Colors

Many graphics functions in Pico-8 have an optional color (which uses the current "pen" color). In Lupi, the color argument is often **mandatory**.

- **Pico-8:** `rectfill(0,0,10,10)` — uses current color
- **Lupi:** `ui.rectfill(0,0,10,10, 7)` — explicit color 7

#### 3. Resolution

Lupi operates natively at a higher resolution than Pico-8, typically **480x270** (widescreen), allowing for richer interfaces and more detailed games.

#### 4. UI Namespace

Graphics functions are grouped in the `ui` namespace. Although some may be global, it is recommended to use `ui.rect`, `ui.print`, etc.

#### 5. Unified Game Loop

In Pico-8, you have `_init()`, `_update()`, and `_draw()` separately. In Lupi, there is only `update(frame)`.

**Pico-8:**

```lua
function _init()
  x = 64
end

function _update()
  if btn(0) then x = x - 1 end
end

function _draw()
  cls()
  spr(1, x, 64)
end
```

**Lupi:**

```lua
-- Color palette (RGB555)
Palette = { 0x0000, 0x0022, 0x02FF, ... }

-- Initialization (code outside function)
x = 240

function update(frame)
  -- Register palette (required every frame)
  for i = 1, #Palette do
    ui.palset(i - 1, Palette[i])
  end

  if ui.btn(LEFT) then x = x - 1 end
  ui.cls(1)
  ui.spr(sprite, x, 135)
end
```

#### 6. Color Palette

In Pico-8, the palette is fixed (16 colors). In Lupi, you define your own palette of up to **256 colors** using `ui.palset(index, color)` with RGB555 values.

> **Important:** The palette must be registered at the beginning of **every frame**.

### 11.2 Equivalence Table

| Pico-8 | Lupi | Notes |
|---|---|---|
| `spr(n, x, y)` | `ui.spr(sheet, x, y)` | Draws the first tile of the sheet. |
| `map(...)` | `ui.map(map_data, ...)` | Requires map object. |
| `print(str, x, y, col)` | `ui.print(str, x, y, col)` | Similar behavior. |
| `btn(i)` | `ui.btn(i)` | Same functionality. |
| `cls(col)` | `ui.cls(col)` | Same functionality. |

### 11.3 New Features

- **Layout System:** Use `ui.layout()` and elements like `Box()` to create complex interfaces automatically — something that would require much manual code in Pico-8.
- **File System:** Lupi runs on an ESP32 and has access to real files via SD card (depending on implementation).

---

## 12. AGENTS.md Reference

Here is an `AGENTS.md` template you can use in your project. This file documents all Lua API functions concisely, allowing AI assistants to understand and correctly use the available functions.

Copy the content below and save it as `AGENTS.md` in your project root to have a quick reference for AI-assisted development.

```markdown
# Lupi Game API Reference

## System Overview
- Resolution: 480x270 pixels (16:9 widescreen)
- Color: 256-color indexed palette (RGB555 format)
- Frame rate: 60 FPS target
- Main callback: `update(frame)` - called 60 times per second with frame number
- **Important:** Palette must be registered each frame using `ui.palset(index, color)`

## Global Constants
- `LEFT`, `RIGHT`, `UP`, `DOWN` - Directional buttons (0-3)
- `BTN_Z`, `BTN_X` - Action buttons (4-5)
- `BTN_F`, `BTN_G` - Secondary action buttons (12-13)
- `BTN_Q`, `BTN_E` - Shoulder buttons (14-15)
- `ALIGN_START`, `ALIGN_CENTER`, `ALIGN_END` - Layout alignment
- `LEFT_TO_RIGHT`, `TOP_TO_BOTTOM` - Layout direction

## Graphics API (ui.*)

### Screen
- `ui.cls([color])` - Clear screen with color (default: 1)
- `ui.clip([x, y, w, h])` - Set/reset clipping region
- `ui.camera([x, y])` - Set/reset camera offset for drawing

### Primitives
- `ui.rect(x0, y0, x1, y1, color)` - Draw rectangle outline
- `ui.rectfill(x0, y0, x1, y1, color)` - Draw filled rectangle
- `ui.circ(x, y, radius, color)` - Draw circle outline
- `ui.circfill(x, y, radius, color)` - Draw filled circle
- `ui.line(x0, y0, x1, y1, color)` - Draw line
- `ui.trisfill(x1, y1, x2, y2, x3, y3, color)` - Draw filled triangle
- `ui.grid(x, y, cell_w, cell_h, data)` - Draw pixel grid from 2D table

### Sprites & Maps
- `ui.spr(sprite_ref, x, y, [flip_x], [flip_y])` - Draw sprite (tile 0)
- `ui.tile(sprite_ref, tile_id, x, y, [flip_x], [flip_y])` - Draw specific tile (0-1023)
- `ui.map(map_data, cam_x, cam_y)` - Draw map with camera offset

### Text
- `ui.print(text, x, y, color)` - Draw text string

### Palette & Patterns
- `ui.palset(index, color)` - Set palette color (index 0-255, color RGB555)
- `ui.fillp([b0, b1, b2, b3, b4, b5, b6, b7])` - Set fill pattern (8 bytes) or reset

### Utility
- `ui.mid(a, b, c)` - Return middle value (useful for clamping)
- `ui.stat(option)` - Get system stats: 0=memory, 1=CPU, 7=FPS

## Input API

### Gamepad
- `ui.btn(button_id, [player])` - Check if button held (returns false or pressure 0-255)
- `ui.btnp(button_id, [player])` - Check if button just pressed (edge detection)
- Player index: 0-2 (default: 0)

### Mouse
- `ui.mouse()` - Returns: x, y, buttons, wheel_x, wheel_y
- buttons bitfield: bit 0 = left, bit 1 = right

### Keyboard
- `ui.peektext()` - Peek next char without removing (returns string or nil)
- `ui.readtext()` - Read and remove next char (returns string or nil)

## Audio API (sfx.*)

- `sfx.music(music_name)` - Play music file (string), use -1 to stop
- `sfx.fx(sample_id, midi_note, [pan])` - Play sound effect (pan: 0.0-1.0, default 0.5)
- `sfx.volume(vol)` - Set global volume (0.0-1.0)

## Layout API (Clay)

### Main Function
- `ui.layout(root_node)` - Render layout tree (call in _draw)

### Elements
- `Box()` - Container element (like div)
- `Text()` - Text element
- `Image(sprite_ref)` - Image element
- `Custom(callback)` - Custom drawing callback

### Builder Methods (chainable)
- `.size.width.set.fixed(px)` / `.set.percentage(0.0-1.0)` / `.set.grow()` / `.set.fit()`
- `.size.height.set.fixed(px)` / `.set.percentage(0.0-1.0)` / `.set.grow()` / `.set.fit()`
- `.padding.set.all(px)` / `.set(x, y)`
- `.gap.set(px)` - Space between children
- `.alignment.horizontal.set(ALIGN_START|ALIGN_CENTER|ALIGN_END)`
- `.alignment.vertical.set(ALIGN_START|ALIGN_CENTER|ALIGN_END)`
- `.set.direction(LEFT_TO_RIGHT|TOP_TO_BOTTOM)`
- `.color.set(palette_index)` - Background color
- `.corner.set.radius(px)` - Rounded corners
- `.add.child(node)` - Add child element
- `.set.visible(bool)` - Show/hide

### Text-specific
- `.content(string)` - Set text content
- `.letter_spacing.set(px)` - Letter spacing
- `.line_height.set(px)` - Line height

### Custom-specific
- Callback receives: x, y, width, height

## Example Game Loop

```lua
-- Define palette (RGB555 colors, indices 0-99)
Palette = {
    0x0000, 0x0000, 0x0022, 0x02FF, 0x6FF7, 0x7EE7, 0x0001, 0x5FF7,
    0x2D00, 0x01F5, 0x3F7F, 0x2108, 0x5B5E, 0x4620, 0x00CA, 0x3DEF,
    -- ... add more colors as needed
}

-- Initialize game state (runs once when script loads)
player = { x = 240, y = 135 }

function update(frame)
    -- Register palette colors (required each frame)
    for i = 1, #Palette do
        ui.palset(i - 1, Palette[i])
    end

    -- Input handling
    if ui.btn(LEFT) then player.x = player.x - 2 end
    if ui.btn(RIGHT) then player.x = player.x + 2 end
    if ui.btn(UP) then player.y = player.y - 2 end
    if ui.btn(DOWN) then player.y = player.y + 2 end

    -- Clamp to screen
    player.x = ui.mid(0, player.x, 480)
    player.y = ui.mid(0, player.y, 270)

    -- Drawing
    ui.cls(1)  -- Clear with color 1
    ui.circfill(player.x, player.y, 8, 7)  -- Draw player
    ui.print("Frame: " .. frame, 10, 10, 7)
end
```
```

---

**End of Documentation**

*This is provisional documentation for study purposes. Changes occur frequently. Last updated: 26/03/2026 2:48.*
