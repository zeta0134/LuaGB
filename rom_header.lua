-- given an entire rom (as a string reference),
-- print out the various header data for debugging

function read_file_into_byte_array(file)
  byte_array = {}
  byte = file:read()
  i = 0
  while byte do
    byte_array[i] = byte
    byte = file:read()
    i = i + 1
  end
  return byte_array
end

function extract_string(data, s, e)
  str = ""
  for i = s, e do
    if data[i] ~= 0 then
      str = str .. string.char(data[i])
    end
  end
  return str
end

cartridge_types = {}
cartridge_types[0x00] = "ROM ONLY"
cartridge_types[0x01] = "MBC1"
cartridge_types[0x02] = "MBC1+RAM"
cartridge_types[0x03] = "MBC1+RAM+BATTERY"
cartridge_types[0x05] = "MBC2"
cartridge_types[0x06] = "MBC2+BATTERY"

function print_cartridge_header(data)
  --convert the title data into a lua string
  title = extract_string(data, 0x134, 0x143)
  manufacturer = extract_string(data, 0x13F, 0x142)
  print("Title: ", title)
  print("Manufacturer: ", manufacturer)

  cgb = bit32.band(data[0x143], 0x8) ~= 0
  if cgb then
    print("Color: YES")
  else
    print("Color: NO")
  end

  licencee = extract_string(data, 0x144, 0x145)
  print("Licencee: ", licencee)

  sgb = data[0x146] == 0x3
  if sgb then
    print("SuperGB: YES")
  else
    print("SuperGB: NO")
  end

  cart_type = cartridge_types[data[0x147]]
  if cart_type then
    print("Type: " .. cart_type)
  else
    print("Type: UNKNOWN!!")
  end

  rom_size = data[0x148]
  if rom_size < 0x8 then
    print("Rom Size: " .. bit32.lshift(32, rom_size))
  end

  ram_size = data[0x149]
  if ram_size == 0 then
    print("Ram Size: 0k")
  end
  if ram_size == 1 then
    print("Ram Size: 2k")
  end
  if ram_size == 2 then
    print("Ram Size: 8k")
  end
  if ram_size == 3 then
    print("Ram Size: 32k (banked)")
  end

  japanese = data[0x14A]
  if japanese then
    print("Japan Only: Iie")
  else
    print("Japan Only: Hai")
  end

  licencee_code = data[0x14B]
  print("Licencee Code: ", licencee_code)
end
