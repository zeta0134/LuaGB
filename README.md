# LuaGB
A gameboy emulator written in Pure Lua. Work in progress.

This is designed to be fairly cross platform, and currently consists of a gameboy module which contains the emulator, and a Love2D interface, presently the only supported platform.

## Build Instructions
On any Linux system, make sure to install Love 0.10.2, gnu make, and the "zip" utility. Drop any .gb files you'd like to play with in the games folder first, then just run the makefile to generate LuaGB.love. Due to a limitation in the way Love2D accesses the filesystem, games need to be preloaded during the make step.

Please only use commercial ROMs you have legally obtained yourself; in the US at least, this means you need to personally rip them from original cartridges with your own hardware. For free homebrew, I've been testing with several games and demos from PDRoms:
http://pdroms.de/

## Usage Instructions
```
love LuaGB.love games/path/to/game.gb
```

## Known Issues
This emulator is *not particularly fast* and while I'm aiming to make it as performant as possible, the present focus on accuracy means that even my i7 is unable to play most games at full speed. Part of this is due to Lua performance, but I remained convinced that gains can be made in speed with algorithmic improvements. Working correctly first, fast later.

There are some major CPU bugs present that I'm still debugging and tracking down, so many games do not play correctly, or have graphical or logical errors. Audio is entirely missing, and likely will remain that way unless the speed issues are addressed.

Battery backed saves are technically emulated, but not written out to disk, so progress in games utilizing the feature will be lost when closing the emulator. Save states are supported however.

The debug features, especially the VRAM viewer, are *quite* slow. You can toggle the debug features on and off individually using the number pad, or disable debug mode entirely by pressing "D" at any point.
