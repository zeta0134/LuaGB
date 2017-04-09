local bit32 = require("bit")

local Cache = {}

function Cache.new(graphics)
  local cache = {}

  cache.tiles = {}
  cache.tiles_h_flipped = {}
  cache.map_0 = {}
  cache.map_1 = {}
  cache.map_0_attr = {}
  cache.map_1_attr = {}
  cache.oam = {}

  cache.reset = function()
    for i = 0, 768 - 1 do
      cache.tiles[i] = {}
      cache.tiles_h_flipped[i] = {}
      for x = 0, 7 do
        cache.tiles[i][x] = {}
        cache.tiles_h_flipped[i][x] = {}
        for y = 0, 7 do
          cache.tiles[i][x][y] = 0
          cache.tiles_h_flipped[i][x][y] = 0
        end
      end
    end

    for x = 0, 31 do
      cache.map_0[x] = {}
      cache.map_1[x] = {}
      cache.map_0_attr[x] = {}
      cache.map_1_attr[x] = {}
      for y = 0, 31 do
        cache.map_0[x][y] = cache.tiles[0]
        cache.map_1[x][y] = cache.tiles[0]
        cache.map_0_attr[x][y] = {}
        cache.map_1_attr[x][y] = {}

        if graphics.gameboy.type == graphics.gameboy.types.color then
          cache.map_0_attr[x][y].palette = graphics.palette.color_bg[0]
        else
          cache.map_0_attr[x][y].palette = graphics.palette.bg
        end
        cache.map_0_attr[x][y].bank = 0
        cache.map_0_attr[x][y].horizontal_flip = false
        cache.map_0_attr[x][y].vertical_flip = false
        cache.map_0_attr[x][y].priority = false

        if graphics.gameboy.type == graphics.gameboy.types.color then
          cache.map_1_attr[x][y].palette = graphics.palette.color_bg[0]
        else
          cache.map_1_attr[x][y].palette = graphics.palette.bg
        end
        cache.map_1_attr[x][y].bank = 0
        cache.map_1_attr[x][y].horizontal_flip = false
        cache.map_1_attr[x][y].vertical_flip = false
        cache.map_1_attr[x][y].priority = false
      end
    end

    for i = 0, 39 do
      cache.oam[i] = {}
      cache.oam[i].x = 0
      cache.oam[i].y = 0
      cache.oam[i].tile = cache.tiles[0]
      cache.oam[i].upper_tile = cache.tiles[0]
      cache.oam[i].lower_tile = cache.tiles[1]
      cache.oam[i].bg_priority = false
      cache.oam[i].horizontal_flip = false
      cache.oam[i].vertical_flip = false
      if graphics.gameboy.type == graphics.gameboy.types.color then
        cache.oam[i].palette = graphics.palette.color_obj[0]
      else
        cache.oam[i].palette = graphics.palette.bg
      end
    end
  end

  cache.refreshOamEntry = function(index)
    local y = graphics.oam[0xFE00 + index * 4 + 0] - 16
    local x = graphics.oam[0xFE00 + index * 4 + 1] - 8
    local tile_index = graphics.oam[0xFE00 + index * 4 + 2]
    local flags = graphics.oam[0xFE00 + index * 4 + 3]

    cache.oam[index].x = x
    cache.oam[index].y = y
    local vram_bank = 0
    if graphics.gameboy.type == graphics.gameboy.types.color then
      vram_bank = bit32.rshift(bit32.band(0x08, flags), 3)
    end
    cache.oam[index].bg_priority = bit32.band(0x80, flags) ~= 0
    cache.oam[index].vertical_flip = bit32.band(0x40, flags) ~= 0
    cache.oam[index].horizontal_flip = bit32.band(0x20, flags) ~= 0
    if graphics.gameboy.type == graphics.gameboy.types.color then
      local palette_index = bit32.band(0x07, flags)
      cache.oam[index].palette = graphics.palette.color_obj[palette_index]
    else
      if bit32.band(0x10, flags) ~= 0 then
        cache.oam[index].palette = graphics.palette.obj1
      else
        cache.oam[index].palette = graphics.palette.obj0
      end
    end
    if cache.oam[index].horizontal_flip then
      cache.oam[index].tile =       cache.tiles_h_flipped[tile_index + (384 * vram_bank)]
      cache.oam[index].upper_tile = cache.tiles_h_flipped[bit32.band(tile_index, 0xFE) + (384 * vram_bank)]
      cache.oam[index].lower_tile = cache.tiles_h_flipped[bit32.band(tile_index, 0xFE) + 1 + (384 * vram_bank)]
    else
      cache.oam[index].tile =       cache.tiles[tile_index + (384 * vram_bank)]
      cache.oam[index].upper_tile = cache.tiles[bit32.band(tile_index, 0xFE) + (384 * vram_bank)]
      cache.oam[index].lower_tile = cache.tiles[bit32.band(tile_index, 0xFE) + 1 + (384 * vram_bank)]
    end

  end

  cache.refreshAttributes = function(map_attr, x, y, address)
    local data = graphics.vram[address + (16 * 1024)]
    if graphics.gameboy.type == graphics.gameboy.types.color then
      map_attr[x][y].palette = graphics.palette.color_bg[bit32.band(data, 0x07)]
    else
      map_attr[x][y].palette = graphics.palette.bg
    end
    map_attr[x][y].bank = bit32.rshift(bit32.band(data, 0x08), 3)
    map_attr[x][y].horizontal_flip = bit32.rshift(bit32.band(data, 0x20), 5) ~= 0
    map_attr[x][y].vertical_flip = bit32.rshift(bit32.band(data, 0x40), 6) ~= 0
    map_attr[x][y].priority = bit32.rshift(bit32.band(data, 0x80), 7) ~= 0
  end

  cache.refreshTile = function(address, bank)
    -- Update the cached tile data
    local tile_index = math.floor((address - 0x8000) / 16) + (384 * bank)
    local y = math.floor((address % 16) / 2)
    -- kill the lower bit
    address = bit32.band(address, 0xFFFE)
    local lower_bits = graphics.vram[address + (16 * 1024 * bank)]
    local upper_bits = graphics.vram[address + (16 * 1024 * bank) + 1]
    for x = 0, 7 do
      local palette_index = bit32.band(bit32.rshift(lower_bits, 7 - x), 0x1) + (bit32.band(bit32.rshift(upper_bits, 7 - x), 0x1) * 2)
      cache.tiles[tile_index][x][y] = palette_index
      cache.tiles_h_flipped[tile_index][7 - x][y] = palette_index
    end
  end

  cache.refreshTiles = function()
    for i = 0, 384 - 1 do
      for y = 0, 7 do
        cache.refreshTile(0x8000 + i * 16 + y * 2, 0)
        cache.refreshTile(0x8000 + i * 16 + y * 2, 1)
      end
    end
  end

  cache.refreshTileIndex = function(x, y, address, map, attr)
    local tile_index = graphics.vram[address + (y * 32) + x]
    if graphics.registers.tile_select == 0x9000 then
      if tile_index > 127 then
        tile_index = tile_index - 256
      end
      -- add offset to re-root at tile 256 (so effectively, we read from tile 192 - 384)
      tile_index = tile_index + 256
    end
    if attr[x][y].bank == 1 then
      tile_index = tile_index + 384
    end
    if attr[x][y].horizontal_flip then
      map[x][y] = cache.tiles_h_flipped[tile_index]
    else
      map[x][y] = cache.tiles[tile_index]
    end
  end

  cache.refreshTileMap = function(address, map, attr)
    for x = 0, 31 do
      for y = 0, 31 do
        cache.refreshTileIndex(x, y, address, map, attr)
      end
    end
  end

  cache.refreshTileMaps = function()
    cache.refreshTileMap(0x9800, cache.map_0, cache.map_0_attr)
    cache.refreshTileMap(0x9C00, cache.map_1, cache.map_1_attr)
  end

  cache.refreshTileAttributes = function()
    for x = 0, 31 do
      for y = 0, 31 do
        cache.refreshAttributes(cache.map_0_attr, x, y, 0x9800 + (y * 32) + x)
        cache.refreshAttributes(cache.map_1_attr, x, y, 0x9C00 + (y * 32) + x)
      end
    end
  end

  cache.refreshAll = function()
    cache.refreshTiles()
    cache.refreshTileAttributes()
    cache.refreshTileMaps()
  end

  return cache
end

return Cache
