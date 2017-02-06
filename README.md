# LuaGB
A gameboy emulator written in Pure Lua. Work in progress.

This is designed to be fairly cross platform, and currently consists of a platform-independent gameboy module which contains the emulator, and a Love2D interface, presently the only supported platform.

## Build Instructions
On any Linux system, make sure to install Love 0.10.2, gnu make, and the "zip" utility. Then just run "make" in the source folder. Once built, the resulting .love file works just fine on Windows systems, provided Love 0.10.2 is installed. I have decent success building the project with Bash on Windows 10; the makefile is also simple enough to port to something else if you're so inclinded. Pull requests welcome!

If you'd like games embedded in the resulting .love file, you may drop then in the games folder before running make. Alternately, games will load from the save directory. Due to a by-design limitation with Love2D's filesystem libraries, games may only be loaded from these two locations.

Please only use commercial ROMs you have legally obtained yourself; in the US at least, this means you need to personally rip them from original cartridges with your own hardware. For free homebrew, I've been testing with several games and demos from PDRoms:
http://pdroms.de/

If you're interested in purchasing a fantastic cartridge ripper, I own and use the Joey Generation 3. Note that BennVenn makes these by hand, so if his shop is out of stock, check back in a few days:
http://bennvenn.myshopify.com/products/reader-writer-gen2


## Usage Instructions
```
love LuaGB.love [games/path/to/game.gb]
```

Unless you provide a game at the command line, the following interface will be displayed at startup:
![filebrowser](http://i.imgur.com/rz0k1pB.png "Filebrowser")

This interface works similarly to a real gameboy, so you operate it using the buttons. A or Start will run the selected game. Press
ESC during gameplay to bring up this menu.

Use keyboard F1-F8 to create save states, and 1-8 to load existing states. At any time, press D to enter debug mode, which displays
additional keyboard mappings.

## Known Issues
This emulator is *not particularly fast* and while I'm aiming to make it as performant as possible, the present focus on accuracy means that even my i7 is unable to play every game at full speed. Part of this is due to Lua performance quirks, but I remained convinced that gains can be made in speed with algorithmic improvements. Working correctly first, fast later.

Audio is implemented and working, but an issue with Love2D's audio library makes it difficult to stream it cleanly. Audio does play, but there are audible clicks and pops that I can't presently do anything about. The considerable lag in audio is by design, to minimize these artifacts. A new QueueableAudio type is due for the next major Love2D version; once that's out I can fix this issue properly.

The debug features, especially the VRAM viewer, are *somewhat slow*. You can toggle the debug features on and off individually using the number pad, but it's best to stick to the default non-debug mode for gameplay.

I still have not implemented every cartridge type, and some more advanced features (like the RTC clock on MBC3) are incomplete or missing entirely. I welcome bug reports, but please observe the console output when a game won't boot; if it complains about an Unknown MBC type, that's likely the real issue. I need to order physical cartridges for every MBC type to properly test, and that will take time.

Graphics output is scanline accurate, but not pixel accurate. This is known to affect a few homebrew demos that rely on mid-scanline graphics register updates, but I'm so far unaware of any commercial games affected.

## Bug Reporting
I welcome bug reports of all kinds! Keep in mind though that I will be very slow to respond to bug reports for commercial games that I do not physically own, as I need to order them from Amazon and then rip them to my computer before I can try to reproduce the bug.
