local bit32 = require("bit")

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

      cache.map_0_attr[x][y].palette = 0
      cache.map_0_attr[x][y].bank = 0
      cache.map_0_attr[x][y].horizontal_flip = false
      cache.map_0_attr[x][y].vertical_flip = false
      cache.map_0_attr[x][y].priority = false

      cache.map_1_attr[x][y].palette = 0
      cache.map_1_attr[x][y].bank = 0
      cache.map_1_attr[x][y].horizontal_flip = false
      cache.map_1_attr[x][y].vertical_flip = false
      cache.map_1_attr[x][y].priority = false
    end
  end
end

cache.refreshAttributes = function(map_attr, x, y, address)
  local data = cache.graphics.vram[address + (16 * 1024)]
  graphics.cache.map_0_attr[x][y].palette = bit32.band(data, 0x07)
  graphics.cache.map_0_attr[x][y].bank = bit32.rshift(bit32.band(data, 0x08), 3)
  graphics.cache.map_0_attr[x][y].horizontal_flip = bit32.rshift(bit32.band(data, 0x20), 5)
  graphics.cache.map_0_attr[x][y].vertical_flip = bit32.rshift(bit32.band(data, 0x40), 6)
  graphics.cache.map_0_attr[x][y].priority = bit32.rshift(bit32.band(data, 0x80), 7)
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

cache.refreshAll = function()
  for i = 0, 384 - 1 do
    cache.refreshTile(0x8000 + i * 2, 0)
    cache.refreshTile(0x8000 + i * 2, 1)
  end

  for x = 0, 31 do
    for y = 0, 31 do
      cache.map_0[x][y] = cache.graphics.vram[0x9800 + (y * 32) + x]
      cache.map_1[x][y] = cache.graphics.vram[0x9C00 + (y * 32) + x]
      cache.refreshAttributes(cache.map_0_attr, x, y, 0x9800 + (y * 32) + x)
      cache.refreshAttributes(cache.map_1_attr, x, y, 0x9C00 + (y * 32) + x)
    end
  end
end

return cache
