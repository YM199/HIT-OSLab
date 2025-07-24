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

! 加载系统
ok_load:
	cli	! 关闭中断
	mov	ax, #SYSSEG
	mov	ds, ax ! 设置数据段地址0x1000
	xor	ax, ax ! 清空ax寄存器
	mov	es, ax ! 设置附加段地址0x0000
	mov	cx, #0x2000 ! 设置拷贝字节数为0x2000
	sub	si,si ! ds:si=0x1000:00000
	sub	di,di ! es:di=0x0000:00000
	rep
	movw ! 将ds:si指向的0x2000字节数据拷贝到es:di指向的0x0000:00000字节空间
	mov	ax, #BOOTSEG
	mov	ds, ax ! 设置数据段地址0x07c0
	lidt	idt_48	! 加载中断描述符表
	lgdt	gdt_48	! 加载全局描述符表

! 进入保护模式
	mov	ax,#0x0001
	lmsw	ax		! 设置CR0寄存器的PE位，进入保护模式
	jmpi	0,8		! 跳转至偏移地址0，段选择子8， 使用代码段描述符

gdt:	.word	0,0,0,0		! 空描述符
    ! 代码段描述符
	.word	0x07FF		! 8Mb - limit=2047 (2048*4096=8Mb)
	.word	0x0000		! base address=0x00000
	.word	0x9A00		! code read/exec
	.word	0x00C0		! granularity=4096, 386
    ! 数据段描述符
	.word	0x07FF		! 8Mb - limit=2047 (2048*4096=8Mb)
	.word	0x0000		! base address=0x00000
	.word	0x9200		! data read/write
	.word	0x00C0		! granularity=4096, 386

idt_48: .word	0	! 中断描述符表长度为0
	.word	0,0	! 中断描述符表基地址为0
gdt_48: .word	0x7ff	! GDT表长度为2048
	.word	0x7c00+gdt,0	! GDT表基地址为0x7c00+gdt
.org 510
	.word   0xAA55 ! 引导标志

