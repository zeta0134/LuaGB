love:
	@mkdir -p love
	@mkdir -p games

	cp love/main.lua main.lua
	zip -9 -r LuaGB.love main.lua gameboy games UbuntuMono-R.ttf LICENSE.txt UBUNTU_FONT_LICENSE.txt
	rm main.lua

.PHONY : love
