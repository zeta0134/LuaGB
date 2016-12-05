love:
	@mkdir -p love
	@mkdir -p games

	#cp love/main.lua main.lua
	zip -9 -r LuaGB.love gameboy games LICENSE.txt
	cd love && zip -9 -r ../LuaGB.love .
	#rm main.lua

.PHONY : love
