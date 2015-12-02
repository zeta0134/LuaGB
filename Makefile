love:
	@mkdir -p love
	cp love_main.lua love/main.lua
	cp -R gameboy love
	cp -R games love
	cp UbuntuMono-R.ttf love

.PHONY : love
