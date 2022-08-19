# C64-Minesweeper
Minesweeper for the Commodore 64, written in 6502 assembly

## Overview
After programming Minesweeper in Java, I felt like trying something completely
different, and started working on a 6502 assembly version of Minesweeper for the
Commodroe 64. The first mostly-functional version of this program was completed 
in about three days, and much more work has been done since.

In its current state, C64-Minesweeper supports one board size and difficulty --
a 12x20 board with 40 mines. 

Future plans include:
- Compression of whitespace in text screen data
- (Possibly) Add support for custom difficulties (number of mines)

## Building from source
Use the [cc65](https://cc65.github.io/) assembler, cl65, to build the C64
executable with the command `cl65 -o mine.prg -t c64 minesweeper.asm`.

## Running on modern systems
Use a Commodore 64 emulator such as [VICE](https://vice-emu.sourceforge.io/).
With VICE, right click the mine.prg file and open with VICE, or use the
command `x64sc mine.prg`.

## Note to PAL users
This program was written primarily for NTSC systems. If run on a PAL C64,
the clock on the game status screen will run too slowly. To make it work
correctly on PAL systems, change the IRQ_PER_SECOND constant near the beginning
of the source file from 60 to 50.
