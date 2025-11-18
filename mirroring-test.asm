.include "defs.asm"
.include "ram.asm"
.include "constants.asm"
.include "macros.asm"

BOOT_ID = 4
FILE_COUNT = 5

.segment "SIDE1A"
; block 1
.byte $01
.byte "*NINTENDO-HVC*"
.byte $00 ; manufacturer
.byte "FMT" ; game name
.byte $20 ; normal disk
.byte $01 ; game version
.byte $00 ; side
.byte $00 ; disk
.byte $00 ; disk type
.byte $00 ; unknown
.byte BOOT_ID ; boot file ID
.byte $FF,$FF,$FF,$FF,$FF
.byte $36 ; year (heisei era)
.byte $03 ; month
.byte $15 ; day
.byte $49 ; country
.byte $61, $00, $00, $02, $00, $00, $00, $00, $00 ; unknown
.byte $36 ; year (heisei era)
.byte $03 ; month
.byte $15 ; day
.byte $00, $80 ; unknown
.byte $00, $00 ; disk writer serial number
.byte $07 ; unknown
.byte $00 ; disk write count
.byte $00 ; actual disk side
.byte $00 ; disk type?
.byte $00 ; disk version?
; block 2
.byte $02
.byte FILE_COUNT

.segment "FILE0_HDR"
; block 3
.import __FILE0_DAT_RUN__
.import __FILE0_DAT_SIZE__
.byte $03
.byte 0,0
.byte "TESTPRGM"
.word __FILE0_DAT_RUN__
.word __FILE0_DAT_SIZE__
.byte 0 ; PRG
; block 4
.byte $04
.segment "FILE0_DAT"
.include "main.asm"

.segment "FILE1_HDR"
; block 3
.import __FILE1_DAT_RUN__
.import __FILE1_DAT_SIZE__
.byte $03
.byte 1,1
.byte "VECTORS-"
.word __FILE1_DAT_RUN__
.word __FILE1_DAT_SIZE__
.byte 0 ; PRG
; block 4
.byte $04
; FDS vectors
.segment "FILE1_DAT"
.word NonMaskableInterrupt
.word NonMaskableInterrupt
.word Bypass ; default, used for license screen bypass
.word Reset
.word InterruptRequest

.segment "FILE2_HDR"
; block 3
.import __FILE2_DAT_SIZE__
.import __FILE2_DAT_RUN__
.byte $03
.byte 2,2
.byte "TESTCHAR"
.word __FILE2_DAT_RUN__
.word __FILE2_DAT_SIZE__
.byte 1 ; CHR
; block 4
.byte $04
.segment "FILE2_DAT"
.incbin "Jroatch-chr-sheet.chr"

; This block is the last to load, and enables NMI by "loading" the NMI enable value
; directly into the PPU control register at PPU_CTRL.
; While the disk loader continues searching for one more boot file,
; eventually an NMI fires, allowing us to take control of the CPU before the
; license screen is displayed.
.segment "FILE3_HDR"
; block 3
.import __FILE3_DAT_SIZE__
.import __FILE3_DAT_RUN__
.byte $03
.byte 3,3
.byte "-BYPASS-"
.word PPU_CTRL
.word __FILE3_DAT_SIZE__
.byte 0 ; PRG
; block 4
.byte $04
.segment "FILE3_DAT"
.byte $80 ; enable NMI byte sent to PPU_CTRL

