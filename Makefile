# Makefile for the simple example kernel.
# AS86 LD86  -0 create 16bits code
AS86	=as86 -0 -a
LD86	=ld86 -0

# AS create 32 bits code, 
# -alh turn on list with high level assemble 
AS	=as 
ASFLAGS = --32 -g -alh

#link to 32bit elf format,
#-M , print Map
LD	=ld
LDFLAGS =-m elf_i386 -Ttext 0 -e startup_32  -M  

#debug
BOCHS = bochs

all:	Image

Image: boot system
	dd bs=32 if=boot of=Image skip=1
	objcopy -O binary system head
	cat head >> Image

disk: Image
	dd bs=8192 if=Image of=/dev/fd0
	sync;sync;sync

head.o: head.s
	$(AS) $(ASFLAGS) -o $@ $< > head.lst

system:	head.o 
	$(LD) $(LDFLAGS) head.o  -o system > System.map

boot:	boot.s
	$(AS86) -o boot.o boot.s
	$(LD86) -s -o boot boot.o

clean:
	rm -f Image System.map core boot head *.o system


run:
	$(BOCHS) -q -f tools/bochs/bochsrc/bochsrc-0.00.bxrc
debug:
	$(BOCHS) -q -f tools/bochs/bochsrc/bochsrc-0.00-gdb.bxrc
	debug:
