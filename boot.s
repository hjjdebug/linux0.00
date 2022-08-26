!	boot.s
!
! It then loads the system at 0x10000, using BIOS interrupts. Thereafter
! it disables all interrupts, changes to protected mode, and calls the 

BOOTSEG = 0x07c0
SYSSEG  = 0x1000			! system loaded at 0x10000 (65536).
SYSLEN  = 17				! sectors occupied.

entry start
start:
	jmpi	go,#BOOTSEG
go:	mov	ax,cs
	mov	ds,ax
	mov	ss,ax
	mov	sp,#0x400		! arbitrary value >>512

! ok, we've written the message, now
load_system:
	mov	dx,#0x0000		! 磁头号
	mov	cx,#0x0002		! 扇区号第2个, 第一个是引导扇区
	mov	ax,#SYSSEG		 
	mov	es,ax			! 目标基地址
	xor	bx,bx			! 清bx
	mov	ax,#0x200+SYSLEN	!服务号2, + 数据长度(扇区数), 8K 即可
	int 	0x13
	jnc	ok_load			! 加载到了0x1000 地址
die:	jmp	die

! now we want to move to protected mode ...
ok_load:
	cli			! no interrupts allowed !
	mov	ax, #SYSSEG
	mov	ds, ax
	xor	ax, ax
	mov	es, ax
	mov	cx, #0x2000		!长度8K
	sub	si,si
	sub	di,di
	rep
	movw			! 把数据挪到0地址,那是head.s 代码
	mov	ax, #BOOTSEG	! 进入保护模式	
	mov	ds, ax
	lidt	idt_48		! load idt with 0,0
	lgdt	gdt_48		! load gdt with whatever appropriate

! absolute address 0x00000, in 32-bit protected mode.
	mov	ax,#0x0001	! protected mode (PE) bit
	lmsw	ax		! This is it! 设置保护模式位
	jmpi	0,8		! jmp offset 0 of segment 8 (长跳转，gdt 表中的偏移为8,付给cs,段式寻址，其段地址为0)

gdt:	.word	0,0,0,0		! dummy, 64bits (

	.word	0x07FF		! 8Mb - limit=2047 (2048*4096=8Mb) 代码段,起始偏移位8
	.word	0x0000		! base address=0x00000
	.word	0x9A00		! code read/exec
	.word	0x00C0		! granularity=4096, 386

	.word	0x07FF		! 8Mb - limit=2047 (2048*4096=8Mb) 数据段
	.word	0x0000		! base address=0x00000
	.word	0x9200		! data read/write
	.word	0x00C0		! granularity=4096, 386

idt_48: .word	0		! idt limit=0
	.word	0,0		! idt base=0L
gdt_48: .word	0x7ff		! gdt limit=2048, 256 GDT entries
	.word	0x7c00+gdt,0	! gdt base = 07xxx
.org 510
	.word   0xAA55

