.PHONY : love osx windows all

love:
	@mkdir -p love
	@mkdir -p games

	zip -9 -r LuaGB.love gameboy games LICENSE.txt README.md
	cd love && zip -9 -r ../LuaGB.love .

linux: love
	-rm LuaGB-Linux.tar.gz
	cp vendor/love-win32/Love2D_License.txt .
	tar zcvf LuaGB-Linux.tar.gz LuaGB.love LICENSE.txt README.md Love2D_License.txt
	-rm Love2D_License.txt

osx: love
	cp LuaGB.love vendor/love-mac/LuaGB.app/Contents/Resources
	cd vendor/love-mac && zip -9 -r -y ../../LuaGB-mac.zip LuaGB.app
	-rm vendor/love-mac/LuaGB.app/Contents/Resources/LuaGB.love

all: linux osx
