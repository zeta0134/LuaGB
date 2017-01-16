local bit32 = require("bit")

local rom_header = {}
-- given an entire rom (as a string reference),
-- print out the various header data for debugging

local function read_file_into_byte_array(file)
  local byte_array = {}
  local byte = file:read()
  local i = 0
  while byte do
    byte_array[i] = byte
    byte = file:read()
    i = i + 1
  end
  return byte_array
end

local function extract_string(data, s, e)
  local str = ""
  for i = s, e do
    if data[i] ~= 0 then
      str = str .. string.char(data[i])
    end
  end
  return str
end

rom_header.mbc_names = {}
rom_header.mbc_names[0x00] = "ROM ONLY"
rom_header.mbc_names[0x01] = "MBC1"
rom_header.mbc_names[0x02] = "MBC1+RAM"
rom_header.mbc_names[0x03] = "MBC1+RAM+BATTERY"
rom_header.mbc_names[0x05] = "MBC2"
rom_header.mbc_names[0x06] = "MBC2+BATTERY"

rom_header.parse_cartridge_header = function(data)
  local header = {}
  --convert the title data into a lua string
  header.title = extract_string(data, 0x134, 0x143)
  header.manufacturer = extract_string(data, 0x13F, 0x142)

  local cgb = (bit32.band(data[0x143], 0x80) ~= 0)
  if cgb then
    header.color = true
    header.title = extract_string(data, 0x134, 0x13E)
  else
    header.color = false
  end

  header.licencee = extract_string(data, 0x144, 0x145)

  local sgb = data[0x146] == 0x3
  if sgb then
    header.super_gameboy = true
  else
    header.super_gameboy = false
  end

  header.mbc_type = data[0x147]
  header.mbc_name = rom_header.mbc_names[header.mbc_type]

  local rom_size = data[0x148]
  if rom_size < 0x8 then
    header.rom_size = bit32.lshift(32 * 1024, rom_size)
  end

  local ram_size = data[0x149]
  if ram_size == 0 then
    header.ram_size = 0
  end
  if ram_size == 1 then
    header.ram_size = 2 * 1024
  end
  if ram_size == 2 then
    header.ram_size = 8 * 1024
  end
  if ram_size == 3 then
    header.ram_size = 32 * 1024
  end

  local japanese = data[0x14A]
  if japanese then
    header.japanese = false
  else
    header.japanese = true
  end

  header.licensee_code = data[0x14B]

  return header
end

rom_header.print_cartridge_header = function(header)
  print("Title: ", header.title)
  print("Manufacturer: ", header.manufacturer)

  if header.color then
    print("Color: YES")
  else
    print("Color: NO")
  end

  print("Licencee: ", header.licencee)

  if header.super_gameboy then
    print("SuperGB: YES")
  else
    print("SuperGB: NO")
  end

  if rom_header.mbc_names[header.mbc_type] then
    print("MBC Type: " .. rom_header.mbc_names[header.mbc_type])
  else
    print("MBC Type: UNKNOWN: ", string.format("0x%02X", header.mbc_type))
  end

  print("ROM Size: ", header.rom_size)
  print("RAM Size: ", header.ram_size)

  if header.japanese then
    print("Japanese: Hai")
  else
    print("Japanese: Iie")
  end

  print("Licensee Code: ", header.licensee_code)
end

return rom_header
