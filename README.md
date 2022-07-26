# C64-Minesweeper
Minesweeper for the Commodore 64, written in 6502 assembly

## Overview
After programming Minesweeper in Java, I felt like trying something completely
different, and started working on a 6502 assembly version of Minesweeper for the
Commodroe 64. The first version of this program here was completed in about 
three days.

In its current state, the code is a bit of an unoptimized mess with little
documentation. In the coming commits, I hope to clean it up substantially and
add explanatory comments throughout. Some specific ideas I have are 
consolidation of scratch memory addresses into a few zero page locations,
removal of redundant looping code and replacement with relative jumps to the
necessary operation, and switching to a redefined character mode instead of
bitmap mode.

This last point in particular will simplify a lot of code. For whatever reason,
I didn't consider redefining the character set when making this program and
just used bitmap mode, even though the tile graphics make up a very limited
set of 8x8 cells.

## Building from source
Use the [cc65](https://cc65.github.io/) assembler, cl65, to build the C64
executable with the command `cl65 -o mine.prg -t c64 minesweeper.asm`.

## Running on modern systems
Use a Commodore 64 emulator such as [VICE](https://vice-emu.sourceforge.io/).
With VICE, right click the mine.prg file and open with VICE, or use the
command `x64sc mine.prg`.
