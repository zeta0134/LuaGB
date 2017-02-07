mkdir games
mkdir love
mkdir build

xcopy /S /E /Y /I games love\games
xcopy /S /E /Y /I gameboy love\gameboy
copy /Y LICENSE.txt love\LICENSE.txt
xcopy /S /E /Y /I vendor\love-win32 build

del LuaGB.zip
powershell.exe -nologo -noprofile -command "& { Add-Type -A 'System.IO.Compression.FileSystem'; [IO.Compression.ZipFile]::CreateFromDirectory('love', 'build\LuaGB.love'); }"

rd /s /q love\games
rd /s /q love\gameboy
del love\LICENSE.txt

copy /b build\love.exe+build\LuaGB.love build\LuaGB.exe
del build\LuaGB.love
del build\love.exe
powershell.exe -nologo -noprofile -command "& { Add-Type -A 'System.IO.Compression.FileSystem'; [IO.Compression.ZipFile]::CreateFromDirectory('build', 'LuaGB.zip'); }"
rd /s /q build
