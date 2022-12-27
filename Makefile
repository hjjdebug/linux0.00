# Makefile for the simple example kernel.
# AS86 LD86  -0 create 16bits code
AS86	=as86 -0 -a
LD86	=ld86 -0

AS	=as 
# -32 ,AS create 32 bits code, 
# -alh turn on list with high level assemble 
ASFLAGS = --32 -g -alh

LD	=ld
#-m elf_i386, link to 32bit elf format,
#-Ttext 0 ,要把text段定位与0地址，
#-e startup_32 ,定义入口为startup_32没有意义了，因为这个elf文件 #被抽取成了二进制影像文件
#-M , 生成map 文件
LDFLAGS =-m elf_i386 -Ttext 0 -e startup_32  -M  

#debug
BOCHS = bochs

all:	Image

#boot 删掉前面32bytes才是512bytes 的引导扇区
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
	bochsdbg -q -f tools/bochs/bochsrc/bochsrc-0.00.bxrc
debug:
#	bochsgdb -q -f tools/bochs/bochsrc/bochsrc-0.00-gdb.bxrc
#
#	-s: equals to -gdb tcp:1234. -S: freeze CPU at startup
#	-boot a: a disk is boot disk. -fda Image: file Image is disk a
	qemu -m 16 -boot a -fda Image -s -S
