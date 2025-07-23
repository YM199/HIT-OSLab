!	boot.s
!
! It then loads the system at 0x10000, using BIOS interrupts. Thereafter
! it disables all interrupts, changes to protected mode, and calls the 

BOOTSEG = 0x07c0
SYSSEG  = 0x1000			! system loaded at 0x10000 (65536).
SYSLEN  = 17				! sectors occupied.

entry start
start:
	mov	ax,#BOOTSEG
	mov	ds,ax ! 设置数据 段地址为0x07c0
	mov	ss,ax ! 设置堆栈 段地址为0x07c0
	mov	sp,#0x400 ! 设置栈顶物理地址为0x7c00+0x400=0x8000(栈底为0x7c00)

! 读取head.s
load_system:
	mov	dx,#0x0000 ! 磁盘号0(A盘)
	mov	cx,#0x0002 ! 起始扇区号2
	mov	ax,#SYSSEG
	mov	es,ax ! 设置目标段地址0x1000(代码加载到物理地址0x10000)
	xor	bx,bx ! 偏移地址0
	mov	ax,#0x200+SYSLEN ! AH=0X02(功能号2表示读取扇区) AL=0x11(扇区数量)
	int 0x13 ! 调用BIOS中断读取扇区
	jnc	ok_load ! 如果CF=0,则跳转到ok_load
die:	jmp	die ! 如果CF=1,则死循环

! now we want to move to protected mode ...
ok_load:
	cli			! no interrupts allowed !
	mov	ax, #SYSSEG
	mov	ds, ax
	xor	ax, ax
	mov	es, ax
	mov	cx, #0x2000
	sub	si,si
	sub	di,di
	rep
	movw
	mov	ax, #BOOTSEG
	mov	ds, ax
	lidt	idt_48		! load idt with 0,0
	lgdt	gdt_48		! load gdt with whatever appropriate

! absolute address 0x00000, in 32-bit protected mode.
	mov	ax,#0x0001	! protected mode (PE) bit
	lmsw	ax		! This is it!
	jmpi	0,8		! jmp offset 0 of segment 8 (cs)

gdt:	.word	0,0,0,0		! dummy

	.word	0x07FF		! 8Mb - limit=2047 (2048*4096=8Mb)
	.word	0x0000		! base address=0x00000
	.word	0x9A00		! code read/exec
	.word	0x00C0		! granularity=4096, 386

	.word	0x07FF		! 8Mb - limit=2047 (2048*4096=8Mb)
	.word	0x0000		! base address=0x00000
	.word	0x9200		! data read/write
	.word	0x00C0		! granularity=4096, 386

idt_48: .word	0		! idt limit=0
	.word	0,0		! idt base=0L
gdt_48: .word	0x7ff		! gdt limit=2048, 256 GDT entries
	.word	0x7c00+gdt,0	! gdt base = 07xxx
.org 510
	.word   0xAA55

