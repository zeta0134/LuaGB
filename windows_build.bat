mkdir games
mkdir love

xcopy /S /E /Y /I games love\games
xcopy /S /E /Y /I gameboy love\gameboy
copy /Y LICENSE.txt love\LICENSE.txt

del LuaGB.love
powershell.exe -nologo -noprofile -command "& { Add-Type -A 'System.IO.Compression.FileSystem'; [IO.Compression.ZipFile]::CreateFromDirectory('love', 'LuaGB.love'); }"

rd /s /q love\games
rd /s /q love\gameboy
del love\LICENSE.txt
