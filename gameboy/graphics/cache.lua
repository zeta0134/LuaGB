local bit32 = require("bit")

local Cache = {}

function Cache.new()
  local cache = {}

  cache.tiles = {}
  cache.map_0 = {}
  cache.map_1 = {}
  cache.map_0_attr = {}
  cache.map_1_attr = {}

  cache.reset = function()
    for i = 0, 768 - 1 do
      cache.tiles[i] = {}
      for x = 0, 7 do
        cache.tiles[i][x] = {}
        for y = 0, 7 do
          cache.tiles[i][x][y] = 0
        end
      end
    end

    for x = 0, 31 do
      cache.map_0[x] = {}
      cache.map_1[x] = {}
      cache.map_0_attr[x] = {}
      cache.map_1_attr[x] = {}
      for y = 0, 31 do
        cache.map_0[x][y] = 0
        cache.map_1[x][y] = 0
        cache.map_0_attr[x][y] = {}
        cache.map_1_attr[x][y] = {}

        if cache.graphics.gameboy.type == cache.graphics.gameboy.types.color then
          cache.map_0_attr[x][y].palette = cache.graphics.palette.color_bg[0]
        else
          cache.map_0_attr[x][y].palette = cache.graphics.palette.bg
        end
        cache.map_0_attr[x][y].bank = 0
        cache.map_0_attr[x][y].horizontal_flip = false
        cache.map_0_attr[x][y].vertical_flip = false
        cache.map_0_attr[x][y].priority = false

        if cache.graphics.gameboy.type == cache.graphics.gameboy.types.color then
          cache.map_1_attr[x][y].palette = cache.graphics.palette.color_bg[0]
        else
          cache.map_1_attr[x][y].palette = cache.graphics.palette.bg
        end
        cache.map_1_attr[x][y].bank = 0
        cache.map_1_attr[x][y].horizontal_flip = false
        cache.map_1_attr[x][y].vertical_flip = false
        cache.map_1_attr[x][y].priority = false
      end
    end
  end

  cache.refreshAttributes = function(map_attr, x, y, address)
    local data = cache.graphics.vram[address + (16 * 1024)]
    --map_attr[x][y].palette = bit32.band(data, 0x07)
    if cache.graphics.gameboy.type == cache.graphics.gameboy.types.color then
      map_attr[x][y].palette = cache.graphics.palette.color_bg[bit32.band(data, 0x07)]
    else
      map_attr[x][y].palette = cache.gameboy.palette.bg
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
    local lower_bits = cache.graphics.vram[address + (16 * 1024 * bank)]
    local upper_bits = cache.graphics.vram[address + (16 * 1024 * bank) + 1]
    for x = 0, 7 do
      local palette_index = bit32.band(bit32.rshift(lower_bits, 7 - x), 0x1) + (bit32.band(bit32.rshift(upper_bits, 7 - x), 0x1) * 2)
      cache.tiles[tile_index][x][y] = palette_index
    end
  end

  cache.refreshTiles = function()
    for i = 0, 384 - 1 do
      cache.refreshTile(0x8000 + i * 2, 0)
      cache.refreshTile(0x8000 + i * 2, 1)
    end
  end

  cache.refreshTileIndex = function(x, y, address, map, attr)
    local tile_index = cache.graphics.vram[address + (y * 32) + x]
    if cache.graphics.registers.tile_select == 0x9000 then
      if tile_index > 127 then
        tile_index = tile_index - 256
      end
      -- add offset to re-root at tile 256 (so effectively, we read from tile 192 - 384)
      tile_index = tile_index + 256
    end
    if attr[x][y].bank == 1 then
      tile_index = tile_index + 384
    end
    map[x][y] = tile_index
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
    cache.refreshTileMaps()
    cache.refreshTileAttributes()
  end

  return cache
end

return Cache
