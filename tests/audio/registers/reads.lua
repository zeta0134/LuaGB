describe("Audio", function()
  describe("Registers", function()
    setup(function()
      -- Create a mock audio module with stubbed out external modules
      Audio = require("gameboy/audio/init")
      Io = require("gameboy/io")
      Memory = require("gameboy/memory")
      Timers = require("gameboy/timers")
      bit32 = require("bit")
    end)
    before_each(function()
      local modules = {}
      modules.memory = Memory.new()
      modules.io = Io.new(modules)
      modules.timers = Timers.new(modules)
      audio = Audio.new(modules)
      -- create a non-local io reference, to mock writes in tests
      io = modules.io
      ports = io.ports
      memory = modules.memory
    end)
    it("mock audio module can be created", function()
      assert.not_same(audio, nil)
    end)
    it("all registers read back all 1's for their unused bits, length and frequency counters", function()
      local read_masks = {
      --NRx0   NRx1   NRx2   NRx3   NRx4
        0x80,  0x3F,  0x00,  0xFF,  0xBF, --NR1x
        0xFF,  0x3F,  0x00,  0xFF,  0xBF, --NR2x
        0x7F,  0xFF,  0x9F,  0xFF,  0xBF, --NR3x
        0xFF,  0xFF,  0x00,  0x00,  0xBF, --NR4x
        0x00,  0x00,  0x70,               --NR5x
        0xFF,  0xFF,  0xFF,  0xFF,  0xFF, --FF27 -  
        0xFF,  0xFF,  0xFF,  0xFF         --FF2F 
      }
      -- Note: writing 0 to NR52 would interfere with other register reads, since it disables all other
      -- registers, but since we test it last here, there shouldn't be any interference.
      for address = 0xFF10, 0xFF2F do
        local mask = read_masks[address - 0xFF10 + 1]
        memory.write_byte(address, 0x00)
        assert.same(memory.read_byte(address), bit32.bor(0x00, mask))
      end
    end)
  end)
end)