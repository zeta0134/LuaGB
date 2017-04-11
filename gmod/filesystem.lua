local filesystem = {}

filesystem.write = function(name, data, size)
  size = size or data:len()

  local f = file.Open("loveemu/"..name..".dat", "wb", "DATA")
  
  if (not f) then
    return false
  end

  f:Write(data:sub(1, size))

  return true

end

filesystem.read = function(name, size)

    size = size or nil

    local f = file.Open("loveemu/"..name..".dat", "rb", "DATA")

    if (not f) then
        return false, "unable to open file "..name
    end

    local contents = f:Read(size or f:Size())

    return contents, contents:len()
end

filesystem.createDirectory = function(dir)
  return file.CreateDir("loveemu/"..dir)
end

filesystem.getDirectoryItems = function(dir)
  local fs, dirs = file.Find("loveemu/"..dir.."/*.dat", "DATA")
  for i = 1, #fs do
    fs[i] = fs[i]:sub(1, -5) -- remove .dat
  end
  while (dirs[1]) do
    table.insert(fs, table.remove(dirs, 1))
  end
  PrintTable(fs)
  return fs
end
filesystem.isDirectory = function(dir)
  return file.IsDir(dir, "DATA")
end

return filesystem