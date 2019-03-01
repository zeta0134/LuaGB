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
      -- OR with register reads to simulate unused bits
      read_masks = {
      --NRx0   NRx1   NRx2   NRx3   NRx4
        0x80,  0x3F,  0x00,  0xFF,  0xBF, --NR1x
        0xFF,  0x3F,  0x00,  0xFF,  0xBF, --NR2x
        0x7F,  0xFF,  0x9F,  0xFF,  0xBF, --NR3x
        0xFF,  0xFF,  0x00,  0x00,  0xBF  --NR4x
      }
    end)
    it("mock audio module can be created", function()
      assert.not_same(audio, nil)
    end)
    it("channel registers read back all 1's for their unused bits, length and frequency counters", function()
      for address = 0xFF10, 0xFF23 do
        local mask = read_masks[address - 0xFF10 + 1]
        memory.write_byte(address, 0x00)
        assert.same(memory.read_byte(address), bit32.bor(0x00, mask))
      end
    end)
    it("NR52 reads back all 1's for its unused bits", function()
      memory.write_byte(0xFF26, 0x00)
      assert.same(bit32.band(memory.read_byte(0xFF26), 0x70), 0x70)
    end)
    it("Unused memory from 0xFF27 - 0xFF2F reads back 0xFF", function()
      for address = 0xFF27, 0xFF2F do
        memory.write_byte(address, 0x00)
        assert.same(memory.read_byte(address), 0xFF)
      end
    end)
    it("When powered off via NR52, all registers should be written with zero", function()
      -- first, write 0xFF to all channels
      for address = 0xFF10, 0xFF23 do
        memory.write_byte(address, 0xFF)
      end

      -- disable APU entirely; should immediately silence ALL channels
      memory.write_byte(0xFF26, 0x00)
      -- verify that this is the case
      for address = 0xFF10, 0xFF23 do
        local mask = read_masks[address - 0xFF10 + 1]
        assert.same(memory.read_byte(address), bit32.bor(0x00, mask))
      end
      assert.same(memory.read_byte(0xFF24), 0x00)
      assert.same(memory.read_byte(0xFF25), 0x00)
      assert.same(memory.read_byte(0xFF25), 0x70)
    end)
  end)
end)