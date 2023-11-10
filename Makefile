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
Image: boot head
	dd if=boot of=Image bs=32 skip=1
	objcopy -O binary head bin_head
	cat bin_head >> Image

boot:	boot.s
	$(AS86) -o boot.o boot.s
	$(LD86) -s -o boot boot.o

head.o: head.s
	$(AS) $(ASFLAGS) -o $@ $< > head.lst

head:	head.o 
	$(LD) $(LDFLAGS) head.o  -o head > head.map

clean:
	rm -f Image head.map core boot head *.o head

disk: Image
	dd bs=8192 if=Image of=/dev/fd0
	sync;sync;sync


bochs-run:
	$(BOCHS) -q -f tools/bochs/bochsrc/bochsrc-0.00.bxrc
bochs-debug:
	$(BOCHS) -q -f tools/bochs/bochsrc/bochsrc-0.00-gdb.bxrc
run:
#想摆脱Specify the 'raw' format explicitly to remove the restrictions.,用下面命令
	qemu-system-i386 -m 16M -boot a  -drive if=floppy,file=Image,format=raw 
#	qemu-system-i386 -m 16M -boot a -fda Image

debug:
#	qemu-system-i386 -m 16M -boot a -fda Image -s -S 
	qemu-system-i386 -m 16M -boot a  -drive if=floppy,file=Image,format=raw -s -S

