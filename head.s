#  head.s contains the 32-bit startup code.
#  Two L3 task multitasking. The code of tasks are in kernel area, 
#  The kernel code has moved from 0x10000 to 0
SCRN_SEL	= 0x18
TSS0_SEL	= 0x20
LDT0_SEL	= 0x28
TSS1_SEL	= 0X30
LDT1_SEL	= 0x38
.global startup_32
.text
startup_32:
	movl $0x10,%eax
	mov %ax,%ds
	lss init_stack,%esp

# setup base fields of descriptors.
	call setup_idt
	call setup_gdt
	movl $0x10,%eax		# reload all the segment registers
	mov %ax,%ds		# after changing gdt. 
	mov %ax,%es
	mov %ax,%fs
	mov %ax,%gs
	lss init_stack,%esp

# setup up timer 8253 chip.
	movb $0x36, %al
	movl $0x43, %edx
	outb %al, %dx
	movl $11930, %eax        # timer frequency 100 HZ 
	movl $0x40, %edx
	outb %al, %dx
	movb %ah, %al
	outb %al, %dx

# setup timer & system call interrupt descriptors.
	movl $0x00080000, %eax	# eax 高字为0x0008, 内核代码段选择子	
	movw $timer_interrupt, %ax		# 地址低16位
	movw $0x8E00, %dx			#edx 高16位为0,表示地址偏移高16为0, 类型14(中断门),8->存在，特权级0
	movl $0x08, %ecx              # The PC default timer int.
	lea idt(,%ecx,8), %esi		# 时钟是8号中断源.
	movl %eax,(%esi) 
	movl %edx,4(%esi)

	#设定0x80号中断门服务程序
	movw $system_interrupt, %ax	# 选择子仍然是0x0008, 低16位地址system_interrrupt
	movw $0xef00, %dx			# 类型15(陷阱门), e->存在，特权级3, 高16位地址依旧为0
	movl $0x80, %ecx			# 系统中断是0x80号中断源
	lea idt(,%ecx,8), %esi
	movl %eax,(%esi) 
	movl %edx,4(%esi)

# unmask the timer interrupt.
#	movl $0x21, %edx
#	inb %dx, %al
#	andb $0xfe, %al
#	outb %al, %dx 

# Move to user mode (task 0)
	pushfl
	andl $0xffffbfff, (%esp)
	popfl
	movl $TSS0_SEL, %eax
	ltr %ax			# 加载任务寄存器，这个描述符确定了任务状态段的基址和大小
	movl $LDT0_SEL, %eax
	lldt %ax 		# 加载ldt表，这个描述符确定了ldt表的基址和大小
	movl $0, current
	sti
	pushl $0x17		#任务0 数据段选择子
	pushl $init_stack
	pushfl
	pushl $0x0f		#任务0 代码段选择子
	pushl $task0
	iret		# 代码段cs=0x0f, 所以请求的特权级是3, 且使用ldt 表,ldt表选择子0x8
				# 堆栈段ss=0x17, 所以请求的优先级是3,使用ldt表，ldt表选择子0x10
				# ldt表中代码段描述符应该和gdt中代码段描述符一致，以便能够有共同的符号编址
				# 同理数据段也一样，如果数据段与代码段共用一个起始地址，则代码与数据能统一编址
				# 该程序就是这么做的，这好像叫地址的平坦模式吧！

/****************************************/
setup_gdt:
	lgdt lgdt_opcode
	ret

setup_idt:
	lea ignore_int,%edx		/* 两种写法一样  mov $ignore_int,%edx */
	movl $0x00080000,%eax
	movw %dx,%ax		/* selector = 0x0008 = cs */
	movw $0x8E00,%dx	/* interrupt gate - dpl=0, present */
	lea idt,%edi
	mov $256,%ecx
rp_sidt:
	movl %eax,(%edi)
	movl %edx,4(%edi)
	addl $8,%edi
	dec %ecx
	jne rp_sidt
	lidt lidt_opcode
	ret

# -----------------------------------
write_char:
	push %gs
	pushl %ebx
#	pushl %eax
	mov $SCRN_SEL, %ebx
	mov %bx, %gs		#重设gs段寄存器，使它执行一个新的段基址0xb8000
	movl scr_loc, %ebx		# scr_loc 是个内存, 最初设置为0
	shl $1, %ebx				# 每个位置按word存储，低byte是字符，高byte是属性
	movb %al, %gs:(%ebx)	#操作该基址下的内存
	shr $1, %ebx
	incl %ebx
	cmpl $2000, %ebx		# 80*25 字符显示
	jb 1f
	movl $0, %ebx
1:	movl %ebx, scr_loc	
#	popl %eax
	popl %ebx
	pop %gs
	ret

/***********************************************/
/* This is the default interrupt "handler" :-) */
.align 2
ignore_int:
	push %ds
	pushl %eax
	movl $0x10, %eax
	mov %ax, %ds
	movl $67, %eax            /* print 'C' */
	call write_char
	popl %eax
	pop %ds
	iret

/* Timer interrupt handler */ 
.align 2
timer_interrupt:
	push %ds
	pushl %eax
	movl $0x10, %eax
	mov %ax, %ds		#设置内核数据段
	movb $0x20, %al		#发送EOI, 使8259可以继续响应硬件中断请求
	outb %al, $0x20
	movl $1, %eax
	cmpl %eax, current
	je 1f
	movl %eax, current	#把1 存到current
	ljmp $TSS1_SEL, $0	#ljmp tss_selector 引起任务切换,ldt表选择子在tss段指定项中保存
	jmp 2f
1:	movl $0, current
	ljmp $TSS0_SEL, $0
2:	popl %eax
	pop %ds
	iret

/* system call handler */
/* 系统中断时，cs, ss 是如何得到的？
系统中断是cs段寄存器,cs: 0x8 ,中断门设定的段选择子,偏移system_interrupt
             ss段寄存器,ss: 0x10, TSS段中设定的ss0 ,偏移krn_stk0 or krn_stk1, 看中断是那个任务调用的
			 不同任务，对应了不同的tss段，由tr寄存器指定, tr寄存器由任务切换ljmp tssSelector 转换
			 */
.align 2
system_interrupt:
	push %ds
	pushl %edx
	pushl %eax
	movl $0x10, %edx
	mov %dx, %ds	# 重设ds寄存器
	call write_char
	popl %eax
	popl %edx
	pop %ds
	iret

/*********************************************/
current:.long 0
scr_loc:.long 0

.align 2
lidt_opcode:
	.word 256*8-1		# idt contains 256 entries
	.long idt		# This will be rewrite by code. 
lgdt_opcode:
	.word (end_gdt-gdt)-1	# so does gdt 
	.long gdt		# This will be rewrite by code.

	.align 8
idt:	.fill 256,8,0		# idt is uninitialized

gdt:	.quad 0x0000000000000000	/* NULL descriptor */
	.quad 0x00c09a00000007ff	/* 8Mb 0x08, base = 0x00000,段限长8M,段类型a */
	.quad 0x00c09200000007ff	/* 8Mb 0x10, base =0x0, 段限长8M,段类型2*/
	.quad 0x00c0920b80000002	/* screen 0x18 - for display */
#	.word 0x0002,0x8000,0x920b,0x00c0 /* 段限长0x0002*4K base = 0x0b8000,属性c0高4bit,颗粒度，d/b位，保留2位 */
#	低4bit是段限长高位(段限长20bits)	属性92. 前4bit, P,DPL,S(0为系统段，1为代码或数据),后4bit为段类型2

#		段限长， 偏移低16, 属性+偏移16-24, 偏移24-32位,,粒度为0,byte为单位,属性e,描述符优先级为3级.
	.word 0x0068, tss0, 0xe900, 0x0000	# TSS0 descr 0x20	,段类型为9	起始地址tss0,段限长0x68,24bit-20bit的0(粒度为byte,d/b为0,2bit保留）
	.word 0x0040, ldt0, 0xe200, 0x0000	# LDT0 descr 0x28	,段类型为2  起始地址ldt0,段限长0x40,24bit-20bit的0(粒度为byte,d/b为0,2bit保留）
	.word 0x0068, tss1, 0xe900, 0x0000	# TSS1 descr 0x30
	.word 0x0040, ldt1, 0xe200, 0x0000	# LDT1 descr 0x38
end_gdt:
	.fill 128,4,0
init_stack:                          # Will be used as user stack for task0.
	.long init_stack
	.word 0x10

/*************************************/
.align 8
ldt0:	.quad 0x0000000000000000
	.quad 0x00c0fa00000003ff	# 0x0f, base = 0x00000,限长1k*4096	代码段
#	.quad 0x00c09a00000003ff	# 0x08, base = 0x00000, 产生异常实验,权限变动
	.quad 0x00c0f200000003ff	# 0x17, base = 0,限长1k*4K	数据段

tss0:	.long 0 			/* back link */
	.long krn_stk0, 0x10		/* esp0, ss0 */
	.long 0, 0, 0, 0, 0		/* esp1, ss1, esp2, ss2, cr3 */
	.long 0, 0, 0, 0, 0		/* eip, eflags, eax, ecx, edx */
	.long 0, 0, 0, 0, 0		/* ebx esp, ebp, esi, edi */
	.long 0, 0, 0, 0, 0, 0 		/* es, cs, ss, ds, fs, gs */
	.long LDT0_SEL, 0x8000000	/* ldt, trace bitmap */

	.fill 128,4,0
krn_stk0:
#	.long 0

/************************************/
.align 8
ldt1:	.quad 0x0000000000000000
	.quad 0x00c0fa00000003ff	# 0x0f, base = 0x00000,与gdt代码段一致,段限4Mb,属性fa,说明描述符优先级为3,代码/数据bit, 类型为a(代码）
	.quad 0x00c0f200000003ff	# 0x17

tss1:	.long 0 			/* back link */
	.long krn_stk1, 0x10		/* esp0, ss0 */
	.long 0, 0, 0, 0, 0		/* esp1, ss1, esp2, ss2, cr3 */
	.long task1, 0x200		/* eip, eflags */
	.long 0, 0, 0, 0		/* eax, ecx, edx, ebx */
	.long usr_stk1, 0, 0, 0		/* esp, ebp, esi, edi */
	.long 0x17,0x0f,0x17,0x17,0x17,0x17 /* es, cs, ss, ds, fs, gs */
	.long LDT1_SEL, 0x8000000	/* ldt, trace bitmap */

	.fill 128,4,0
krn_stk1:

/************************************/
task0:
	movl $0x17, %eax
	movw %ax, %ds			/* ds not set yet, so set it */
	movb $65, %al              /* print 'A' */
	int $0x80				/* call system-call */
	movl $0xfff, %ecx
1:	loop 1b
	jmp task0 

task1:
	movl $0x17, %eax
	movw %ax, %ds
	movb $66, %al              /* print 'B' */
	int $0x80
	movl $0xfff, %ecx
1:	loop 1b
	jmp task1


	.fill 128,4,0 
usr_stk1:
/* vim:set fdm=manual: */ 
