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

cache.refreshAll = function()
  
end

return cache
