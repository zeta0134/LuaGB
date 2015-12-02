love:
	@mkdir -p love
	cp love_main.lua love/main.lua
	cp -R gameboy love
	cp -R games love

.PHONY : love
