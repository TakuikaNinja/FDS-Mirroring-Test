GAME=mirroring-test
ZIP_NAME=FDS-Mirroring-Test
ASSEMBLER=ca65
LINKER=ld65

OBJ_FILES=$(GAME).o

all: $(GAME).fds

$(GAME).fds: $(OBJ_FILES) fds.cfg
	$(LINKER) -o $(GAME).fds -C fds.cfg $(OBJ_FILES) -m $(GAME).map.txt -Ln $(GAME).labels.txt --dbgfile $(GAME).dbg

dist: zip
zip: $(ZIP_NAME).zip
$(ZIP_NAME).zip: zip.in
	zip -9 -u $@ -@ < $<

zip.in: $(GAME).fds README.md
	echo $(GAME).fds > $@
	echo README.md >> $@

.PHONY: clean dist zip

clean:
	$(RM) *.o *.fds *.dbg *.nl *.map.txt *.labels.txt *.zip

$(GAME).o: $(wildcard *.asm) Jroatch-chr-sheet.chr

%.o:%.asm
	$(ASSEMBLER) $< -g -o $@
