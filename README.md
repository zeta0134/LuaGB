# LuaGB
A gameboy emulator written in Pure Lua. Approaching feature completeness, but still a work in progress.

This is designed to be fairly cross platform, and currently consists of a platform-independent gameboy module which contains the emulator, and a Love2D interface, presently the only supported platform.

## Supported Features

* Pure Lua! Gameboy module should work on any Lua 5.2+ environment with the "bit" library available.
* Original Gameboy (DMG) and Gameboy Color (GBC)
* Decently cycle-approximate graphics
* Working 32KHz audio
* Multiple Palettes for DMG Mode
* SRAM and Save States
* Debug Panels for VRAM, Audio, IO and Disassembly
* Built-in filebrowser, drawn in software for easy porting

## Notable Missing Features

* Super Gameboy support (planned)
* Serial Transfer port
* RTC Timer (Pokemon Gold / Crystal)
* HDMA Transfers (Used by a very small handful of games, notably Shantae)

## Build Instructions
On any Linux system, make sure to install Love 0.10.2, GNU make, and the "zip" utility. Then just run "make" in the source folder. On Windows, you can run windows_build.bat, which will produce Love2D.exe, this can then be run from anywhere.

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
![filebrowser](http://i.imgur.com/6eIJDmS.png "Filebrowser")

The first thing you'll want to do if you haven't done so already is load up some games. You can click on the folder icon up top to open up your LuaGB save directory. Any games dropped in here will show up in the file browser on the next run of the program.

This interface works similarly to a real gameboy, so you operate it using the buttons. A or Start will run the selected game. Press ESC during gameplay to bring up this menu.

Use keyboard F1-F8 to create save states, and 1-8 to load existing states. At any time, press D to enter debug mode, which displays additional keyboard mappings.

## Known Issues
This emulator is *not particularly fast* and while I'm aiming to make it as performant as possible, the present focus on accuracy means that even my i7 is unable to play every game at full speed. Part of this is due to Lua performance quirks, but I remained convinced that gains can be made in speed with algorithmic improvements. Working correctly first, fast later.

Audio is implemented and working, but an issue with Love2D's audio library makes it difficult to stream it cleanly. Audio does play, but there are audible clicks and pops that I can't presently do anything about. The considerable lag in audio is by design, to minimize these artifacts. A new QueueableAudio type is due for the next major Love2D version; once that's out I can fix this issue properly.

The debug features, especially the VRAM viewer, are *somewhat slow*. You can toggle the debug features on and off individually using the number pad, but it's best to stick to the default non-debug mode for gameplay.

I still have not implemented every cartridge type, and some more advanced features (like the RTC clock on MBC3) are incomplete or missing entirely. I welcome bug reports, but please observe the console output when a game won't boot; if it complains about an Unknown MBC type, that's likely the real issue. I need to order physical cartridges for every MBC type to properly test, and that will take time.

Graphics output, though nearly cycle accurate, is not perfect. It is close enough for games like Prehistorik Man to display their effects correctly, but some homebrew demos and a few commercial games still have visual problems. Bug reports are very welcome here, as I simply don't have time in the day to test everything, and the small number of games I do have that are giving me obvious visual artifacts are proving difficult to debug.

## Bug Reporting
I welcome bug reports of all kinds! Keep in mind though that I will be slow to respond to bug reports for commercial games that I do not physically own, as I need to order them from Amazon and then rip them to my computer before I can try to reproduce the bug.
