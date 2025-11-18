; Main program code
;
; Formatting:
; - Width: 132 Columns
; - Tab Size: 4, using tab
; - Comments: Column 57

; Reset handler
Reset:
		lda #$00										; clear RAM
		tax
@clrmem:
		sta $00,x
		cpx #4											; preserve BIOS stack variables at $0100~$0103
		bcc :+
		sta $0100,x
:
		sta $200,x
		sta $300,x
		sta $400,x
		sta $500,x
		sta $600,x
		sta $700,x
		inx
		bne @clrmem
		sta PPU_MASK									; mirror is already cleared
		jsr MoveSpritesOffscreen
		jsr InitNametables
		
		lda #BUFFER_SIZE								; set VRAM buffer size
		sta VRAM_BUFFER_SIZE

DoTests:
		jsr CheckNametables
		jsr FDS_STATUS_Reads
		jsr FDS_IO_Toggles

		lda #%10000000									; enable NMIs & change background pattern map access
		sta PPU_CTRL_MIRROR
		sta PPU_CTRL
		
Main:
		jsr ProcessBGMode
		jsr WaitForNMI
		beq Main										; back to main loop

; "NMI" routine which is entered to bypass the BIOS check
Bypass:
		lda #$00										; disable NMIs since we don't need them anymore
		sta PPU_CTRL
		
		lda #<NonMaskableInterrupt						; put real NMI handler in NMI vector 3
		sta NMI_3
		lda #>NonMaskableInterrupt
		sta NMI_3+1
		
		lda #$35										; tell the FDS that the BIOS "did its job"
		sta RST_FLAG
		lda #$ac
		sta RST_TYPE
		
		jmp ($fffc)										; jump to reset FDS
		
; NMI handler
NonMaskableInterrupt:
		bit NMIRunning									; exit if NMI is already in progress
		bmi InterruptRequest
		
		sec
		ror NMIRunning									; set flag for NMI in progress
		
		pha												; back up A/X/Y
		txa
		pha
		tya
		pha
		
		lda NMIReady									; check if ready to do NMI logic (i.e. not a lag frame)
		beq NotReady
		
		jsr SpriteDMA
		
		lda NeedDraw									; transfer Data to PPU if required
		beq :+
		
		jsr WriteVRAMBuffer								; transfer data from VRAM buffer at $0302
		jsr SetScroll									; reset scroll after PPUADDR writes
		dec NeedDraw
		
:
		lda NeedPPUMask									; write PPUMASK if required
		beq :+
		
		lda PPU_MASK_MIRROR
		sta PPU_MASK
		dec NeedPPUMask

:
		dec NMIReady
;		jsr ReadOrDownPads								; read controllers + expansion port

NotReady:
		jsr SetScroll									; remember to set scroll on lag frames
		
		pla												; restore X/Y/A
		tay
		pla
		tax
		pla
		
		asl NMIRunning									; clear flag for NMI in progress before exiting
		
; IRQ handler (unused for now)
InterruptRequest:
		rti

EnableRendering:
		lda #%00001010
	.byte $2c											; [skip 2 bytes]

DisableRendering:
		lda #%00000000									; disable background and queue it for next NMI

UpdatePPUMask:
		sta PPU_MASK_MIRROR
		lda #$01
		sta NeedPPUMask
		rts

MoveSpritesOffscreen:
		lda #$ff										; fill OAM buffer with $ff to move offscreen
		ldx #>oam
		ldy #>oam
		jmp MemFill

InitNametables:
		lda #$20										; top-left
		jsr InitNametable
		lda #$24										; top-right
		jsr InitNametable
		lda #$28										; bottom-left
		jsr InitNametable
		lda #$2c										; bottom-right

InitNametable:
		ldx #$00										; clear nametable & attributes for high address held in A
		ldy #$00
		jmp VRAMFill

WaitForNMI:
		inc NMIReady
:
		lda NMIReady
		bne :-
		rts

; Jump table for main logic
ProcessBGMode:
		lda Mode
		jsr JumpEngine
	.addr BGInit
	.addr DoNothing
		
TestValues:
	.byte ARRANGE::H, ARRANGE::V

Expected:
	.byte $00, ARRANGE::MASK

; Check that $4025.D3 is returned in $4030.D3
; (previously undocumented behaviour)
FDS_STATUS_Reads:
		ldx #$01
		
@loop:
		lda TestValues,x
		sta FDS_CTRL
		lda FDS_STATUS
		and #ARRANGE::MASK
		cmp Expected,x
		beq :+
		inc ReadFails
:
		dex
		bpl @loop
		rts

SetAddr:
		sta PPU_ADDR
		lda #$00
		sta PPU_ADDR
		rts

WriteBytes:
		lda #$55
		sta PPU_DATA
		lda #$aa
		sta PPU_DATA
		rts

; Check that disabling disk registers ($4023.D0 = 0) indirectly sets $4025 = $06, 
; thus resetting the arrangement/mirroring and clearing $4030.D3
; Note that disabling disk registers should still allow reads from the read-only ones...
FDS_IO_Masks:
	.byte %10000011, %10000010

FDS_IO_Toggles:
		jsr InitNametables
		lda #ARRANGE::V									; set $4025.D3 = 1 so the state change can be observed
		sta FDS_CTRL
		ldx #$01
		
@loop:
		lda FDS_IO_Masks,x								; first write ($4023.D0) = 0 must alter the arrangement
		sta FDS_IO_ENABLE
		lda FDS_STATUS
		and #ARRANGE::MASK								; $4030.D3 must change to and stay as 0
		beq :+
		inc IOToggleFails
:
		dex
		bpl @loop
		jsr Delay131									; refresh DRAM rows just in case
		
; Now check that the nametable arrangement/mirroring was altered by the $4023.D0 = 0 write
		lda NametableFails								; preserve previous test result
		pha
		lda #$00
		sta NametableFails
		lda #<H_Arrangement
		sta temp
		lda #>H_Arrangement
		sta temp+1
		jsr CheckNametablePair
		lda NametableFails								; nametable fails here...
		clc
		adc IOToggleFails
		sta IOToggleFails								; ...are now added to IO toggle fails
		pla
		sta NametableFails								; restore previous test result
		rts 

NametableAddrsLo:
	.lobytes H_Arrangement, V_Arrangement

NametableAddrsHi:
	.hibytes H_Arrangement, V_Arrangement

; left column = right column
V_Arrangement:
	.byte $20, $24
	.byte $28, $2c

H_Arrangement:
	.byte $20, $28
	.byte $24, $2c

; Check that $4025.D3 correctly switches the PPU nametable arrangement/mirroring
CheckNametables:
		ldx #$01
@loop:
		lda TestValues,x
		sta FDS_CTRL
		lda NametableAddrsLo,x
		sta temp
		lda NametableAddrsHi,x
		sta temp+1
		ldy #$00
		jsr CheckNametablePair
		ldy #$02
		jsr CheckNametablePair
		dex
		bpl @loop
		rts

; Check nametable mirroring, based on NROM CopyNES plugin
; The general approach is:
; 1. Write $55, $aa to $2x00~$2x01 of one screen
; 2. Read 2 bytes from $2x00~$2x01 of the mirrored screen (no match = fail)
; 3. Write $aa to $2x00 of the mirrored screen
; 4. Read 1 byte from $2x00 of the original screen (no match = fail)
CheckNametablePair:
		lda (temp),y
		jsr SetAddr
		jsr WriteBytes
		iny
		lda (temp),y
		jsr SetAddr
		lda PPU_DATA
		lda PPU_DATA
		cmp #$55
		bne @fail
		lda PPU_DATA
		cmp #$aa
		bne @fail
		
		lda (temp),y
		jsr SetAddr
		lda #$aa
		sta PPU_DATA
		dey
		lda (temp),y
		jsr SetAddr
		lda PPU_DATA
		lda PPU_DATA
		cmp #$aa
		bne @fail
		rts
@fail:
		inc NametableFails								; count number of failed calls
		rts

; Initialise background to display the test results
BGInit:
;		jsr DisableRendering
;		jsr WaitForNMI
		jsr InitNametables
		jsr WaitForNMI
		jsr VRAMStructWrite
	.addr BGData
		jsr PrintResults
		lda #$01										; queue VRAM transfer for next NMI
		sta NeedDraw
		inc Mode
		jmp EnableRendering								; remember to enable BG rendering for the next NMI

PrintResults:
		lda NametableFails
		jsr PrintResult
	vram_addr $2000, 20, 8
		
		lda ReadFails
		jsr PrintResult
	vram_addr $2000, 20, 10
		
		lda IOToggleFails
		jsr PrintResult
	vram_addr $2000, 20, 12
		
		rts

PrintResult:
		cmp #$01
		lda #$00
		rol a
		sta temp+2
		jsr FetchDirectPointer							; fetch pointer into (temp)
		ldx temp+2										; select pass/fail message
		lda StringAddrsLo,x
		sta StringAddr
		lda StringAddrsHi,x
		sta StringAddr+1
			
PrepareString:
		lda temp
		ldx temp+1
		ldy #4
		jsr PrepareVRAMString
		
StringAddr:
	.addr FailMsg
		sta StringStatus
DoNothing:
		rts

; String data
Strings:
	define_string PassMsg, "Pass"
	define_string FailMsg, "Fail"

StringAddrsLo:
	.lobytes PassMsg, FailMsg

StringAddrsHi:
	.hibytes PassMsg, FailMsg

; VRAM transfer structure
BGData:

; Just write to all 16 entries so PPUADDR safely leaves the palette RAM region
; PPUADDR ends at $3F20 before the next write (avoids rare palette corruption)
; (palette entries will never be changed anyway, so we might as well set them all)
Palettes:
	.dbyt $3f00
	encode_length INC1, COPY, PaletteDataSize

.proc PaletteData
	.repeat 8
	.byte $0f, $00, $10, $20
	.endrepeat
.endproc
PaletteDataSize = .sizeof(PaletteData)

TextData:
	vram_addr $2000, 7, 4
	encode_string INC1, COPY, "FDS Mirroring Tests"
	
	vram_addr $2000, 8, 8
	encode_string INC1, COPY, "$4025.D3 W: "

	vram_addr $2000, 8, 10
	encode_string INC1, COPY, "$4030.D3 R: "
	
	vram_addr $2000, 8, 12
	encode_string INC1, COPY, "$4023.D0=0: "
	
	encode_terminator

