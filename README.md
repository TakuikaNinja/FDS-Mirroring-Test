# FDS BIOS Dumper

This program tests the FDS' ability to switch the nametable arrangement/mirroring via $4025.D3, along with some previously undocumented behaviours pertaining to $4030.D3 and $4023.D0.

NESdev forum post: https://forums.nesdev.org/viewtopic.php?p=300488#p300488

## Usage

Simply load the program into an FDS, whether it be original hardware or on an emulator.

The test results will be shown in the following manner:
- $4025.D3 W: Pass/Fail (nametable arrangement must be switchable) 
- $4030.D3 R: Pass/Fail (nametable arrangement status must be readable)
- $4023.D0=0: Pass/Fail ($4023.D0=0 writes must reset nametable arrangement)

Original hardware should pass all tests:
![Screen capture from a Sharp Twin Famicom](/img/FDS-Mirroring-Test_TwinFC.png)

## Building

The CC65 toolchain is required to build the program: https://cc65.github.io/
A simple `make` should then work.

## Acknowledgements

- `Jroatch-chr-sheet.chr` was converted from the following placeholder CHR sheet: https://www.nesdev.org/wiki/File:Jroatch-chr-sheet.chr.png
  - It contains tiles from Generitiles by Drag, Cavewoman by Sik, and Chase by shiru.
- Hardware testing was done using a Sharp Twin Famicom + [FDSKey](https://github.com/ClusterM/fdskey).
- The NESdev Wiki, Forums, and Discord have been a massive help. Kudos to everyone keeping this console generation alive!
  - Thanks to SCSR in particular, who has been analysing the RP2C33 die.
