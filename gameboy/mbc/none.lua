-- Very simple: Map the entire 32k cartridge into lower memory, and be done with it.
local mbc_none = {}
mbc_none.mt = {}
mbc_none.raw_data = {}
mbc_none.external_ram = {}
mbc_none.mt.__index = function(table, address)
  --print("Request read at: ", address)
  return mbc_none.raw_data[address]
end
mbc_none.mt.__newindex = function(table, address, value)
  --do nothing!
  return
end
setmetatable(mbc_none, mbc_none.mt)

return mbc_none
