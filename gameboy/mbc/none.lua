local MbcNone = {}

function MbcNone.new()
  -- Very simple: Map the entire 32k cartridge into lower memory, and be done with it.
  local mbc_none = {}
  mbc_none.mt = {}
  mbc_none.raw_data = {}
  mbc_none.external_ram = {}
  mbc_none.header = {}
  mbc_none.mt.__index = function(table, address)
    return mbc_none.raw_data[address]
  end
  mbc_none.mt.__newindex = function(table, address, value)
    --do nothing!
    return
  end

  mbc_none.load_state = function(self)
    -- Do nothing! This MBC has no state.
  end

  mbc_none.save_state = function(self)
    -- Return nothing! No state to save with this MBC.
    return nil
  end

  mbc_none.reset = function(self, state)
    -- Do nothing! This MBC has no state.
  end

  setmetatable(mbc_none, mbc_none.mt)

  return mbc_none
end

return MbcNone
