mkdir games
mkdir love
mkdir build

xcopy /S /E /Y /I games love\games
xcopy /S /E /Y /I gameboy love\gameboy
xcopy /S /E /Y /I vendor\love-win32 build

del LuaGB-Win32.zip
powershell.exe -nologo -noprofile -command "& { Add-Type -A 'System.IO.Compression.FileSystem'; [IO.Compression.ZipFile]::CreateFromDirectory('love', 'build\LuaGB.love'); }"

rd /s /q love\games
rd /s /q love\gameboy

copy /b build\love.exe+build\LuaGB.love build\LuaGB.exe
copy /Y LICENSE.txt build\LuaGB_License.txt
copy /Y README.md build\README.md
copy /Y build\LuaGB.love LuaGB.love
del build\LuaGB.love
del build\love.exe
powershell.exe -nologo -noprofile -command "& { Add-Type -A 'System.IO.Compression.FileSystem'; [IO.Compression.ZipFile]::CreateFromDirectory('build', 'LuaGB-Win32.zip'); }"
rd /s /q build
