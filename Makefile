love:
	@mkdir -p love
	@mkdir -p games

	zip -9 -r LuaGB.love gameboy games LICENSE.txt README.md
	cd love && zip -9 -r ../LuaGB.love .

	-rm LuaGB_Linux.tar.gz
	cp vendor/love-win32/Love2D_License.txt .
	tar zcvf LuaGB_Linux.tar.gz LuaGB.love LICENSE.txt README.md Love2D_License.txt
	-rm Love2D_License.txt

.PHONY : love
