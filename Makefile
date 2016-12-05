love:
	@mkdir -p love
	@mkdir -p games

	#cp love/main.lua main.lua
	zip -9 -r LuaGB.love gameboy games UbuntuMono-R.ttf LICENSE.txt UBUNTU_FONT_LICENSE.txt
	cd love && zip -9 -r ../LuaGB.love .
	#rm main.lua

.PHONY : love
