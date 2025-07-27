#  head.s contains the 32-bit startup code.
#  Two L3 task multitasking. The code of tasks are in kernel area, 
#  just like the Linux. The kernel code is located at 0x10000. 
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
#	mov %ax,%es
	lss init_stack,%esp # 栈顶指向init_stack

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
	movl $0x00080000, %eax	
	movw $timer_interrupt, %ax
	movw $0x8E00, %dx
	movl $0x08, %ecx              # The PC default timer int.
	lea idt(,%ecx,8), %esi
	movl %eax,(%esi) 
	movl %edx,4(%esi)
	movw $system_interrupt, %ax
	movw $0xef00, %dx
	movl $0x80, %ecx
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
	ltr %ax
	movl $LDT0_SEL, %eax
	lldt %ax 
	movl $0, current
	sti
	pushl $0x17
	pushl $init_stack
	pushfl
	pushl $0x0f
	pushl $task0
	iret

/****************************************/
setup_gdt:
	lgdt lgdt_opcode
	ret

# 将所有256个中断描述符都设置为指向默认的中断处理程序ignore_int
setup_idt:
	lea ignore_int,%edx
	movl $0x00080000,%eax
	movw %dx,%ax		# eax = 0x00080000 + ignore_int
	movw $0x8E00,%dx	
	lea idt,%edi        # edi指向idt表
	mov $256,%ecx
rp_sidt:
	movl %eax,(%edi)    # 将eax的值写入idt表(低32位)，描述符类型是中断门
	movl %edx,4(%edi)   # 将edx的值写入idt表(高32位)，描述符类型是中断门
	addl $8,%edi        # 移动到下一个描述符位置（每个描述符8字节）
	dec %ecx            # 递减计数器
	jne rp_sidt         # 如果计数器不为0，则继续循环
	lidt lidt_opcode    # 加载idt寄存器
	ret

# -----------------------------------
write_char:
	push %gs
	pushl %ebx
#	pushl %eax
	mov $SCRN_SEL, %ebx
	mov %bx, %gs
	movl scr_loc, %ebx
	shl $1, %ebx
	movb %al, %gs:(%ebx)
	shr $1, %ebx
	incl %ebx
	cmpl $2000, %ebx
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
	mov %ax, %ds
	movb $0x20, %al
	outb %al, $0x20
	movl $1, %eax
	cmpl %eax, current
	je 1f
	movl %eax, current
	ljmp $TSS1_SEL, $0
	jmp 2f
1:	movl $0, current
	ljmp $TSS0_SEL, $0
2:	popl %eax
	pop %ds
	iret

/* system call handler */
.align 2
system_interrupt:
	push %ds
	pushl %edx
	pushl %ecx
	pushl %ebx
	pushl %eax
	movl $0x10, %edx
	mov %dx, %ds
	call write_char
	popl %eax
	popl %ebx
	popl %ecx
	popl %edx
	pop %ds
	iret

/*********************************************/
current:.long 0
scr_loc:.long 0

.align 2 # 对齐到2的倍数
lidt_opcode:
	.word 256*8-1	# idt表有256个描述符，每个描述符8字节，所以总大小是256*8-1
	.long idt		# 指向idt表
lgdt_opcode:
	.word (end_gdt-gdt)-1	# 计算gdt表的大小
	.long gdt		# 指向gdt表

.align 8 # 对齐到8的倍数
idt:	.fill 256,8,0		# idt表，未初始化，256个描述符，每个描述符8字节

gdt:	
	.quad 0x0000000000000000	# 空描述符
	.quad 0x00c09a00000007ff	# 内核代码段
	.quad 0x00c09200000007ff	# 内核数据段
	.quad 0x00c0920b80000002	# 内核数据段，屏幕显示

	.word 0x0068, tss0, 0xe900, 0x0	# 任务状态段TSS0
	.word 0x0040, ldt0, 0xe200, 0x0	# 局部描述符表LDT0
	.word 0x0068, tss1, 0xe900, 0x0	# 任务状态段TSS1
	.word 0x0040, ldt1, 0xe200, 0x0	# 局部描述符表LDT1
end_gdt:
	.fill 128,4,0
init_stack:           # 用户栈
	.long init_stack
	.word 0x10

/*************************************/
.align 8
ldt0:	
    .quad 0x0000000000000000 # 空描述符
	.quad 0x00c0fa00000003ff # 用户代码段
	.quad 0x00c0f200000003ff # 用户数据段

# 任务状态段TSS0
tss0:	
	.long 0 			       # 无前一个任务
	.long krn_stk0, 0x10	   # 内核栈0, esp0 = 0x10
	.long 0, 0, 0, 0, 0		   # 特权级1-2的栈指针和段选择子（未使用）
	.long 0, 0, 0, 0, 0		   
	.long 0, 0, 0, 0, 0		   # 通用寄存器状态
	.long 0, 0, 0, 0, 0, 0 	   # 段寄存器状态
	.long LDT0_SEL, 0x8000000  # 局部描述符表LDT0，调试位图

	.fill 128,4,0 # 填充128个4字节的0, 为TSS0分配内核栈空间
krn_stk0:
#	.long 0

/************************************/
.align 8
ldt1:	.quad 0x0000000000000000
	.quad 0x00c0fa00000003ff	# 0x0f, base = 0x00000
	.quad 0x00c0f200000003ff	# 0x17

tss1:	.long 0 			  # 无前一个任务
	.long krn_stk1, 0x10	  # 内核栈1, esp0 = 0x10
	.long 0, 0, 0, 0, 0		  # 特权级1-2的栈指针和段选择子（未使用）
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
	movw %ax, %ds
	movb $65, %al              /* print 'A' */
	int $0x80
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
