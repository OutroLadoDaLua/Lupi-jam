Palette = {
    0x0000, 0x1516, 0x25B4, 0x20A6, 0x1DFD, 0x46FE, 0x7FFF, 0x2532,
    -- ... mais cores, uma lista só, separadas por vírgula
}

function Palette.hex(rgb)
    local r = math.floor(rgb / 0x10000) % 0x100
    local g = math.floor(rgb / 0x100) % 0x100
    local b = rgb % 0x100
    return (math.floor(b / 8) << 10) | (math.floor(g / 8) << 5) | math.floor(r / 8)
end
