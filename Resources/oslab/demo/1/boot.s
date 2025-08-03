!	boot.s
!
! It then loads the system at 0x10000, using BIOS interrupts. Thereafter
! it disables all interrupts, changes to protected mode, and calls the 

! 常量定义
BOOTSEG = 0x07c0                       ! 引导扇区加载的段地址
SYSSEG  = 0x1000                       ! 系统加载的段地址（物理地址0x10000）
SYSLEN  = 17                           ! 系统占用的扇区数量

entry start                            ! 程序入口点
start:                                 ! 启动代码开始
	mov	ax,#BOOTSEG                    ! 将引导扇区段地址加载到AX
	mov	ds,ax                          ! 设置数据段地址为0x07c0
	mov	ss,ax                          ! 设置堆栈段地址为0x07c0
	mov	sp,#0x400                      ! 设置栈顶物理地址为0x7c00+0x400=0x8000（栈底为0x7c00）

! 读取系统文件到内存
load_system:                           ! 加载系统标签
	mov	dx,#0x0000                     ! 设置磁盘号0（A盘）
	mov	cx,#0x0002                     ! 设置起始扇区号2
	mov	ax,#SYSSEG                     ! 设置目标段地址
	mov	es,ax                          ! 设置附加段地址为0x1000（代码加载到物理地址0x10000）
	xor	bx,bx                          ! 清空BX寄存器，设置偏移地址为0
	mov	ax,#0x200+SYSLEN               ! AH=0x02（功能号2表示读取扇区），AL=0x11（扇区数量）
	int 0x13                           ! 调用BIOS中断13h读取扇区
	jnc	ok_load                        ! 如果CF=0（无错误），则跳转到ok_load
die:	jmp	die                        ! 如果CF=1（有错误），则进入死循环

! 系统加载完成后的处理
ok_load:                               ! 加载成功标签
	cli	                               ! 关闭中断（禁止中断）
	mov	ax, #SYSSEG                    ! 将系统段地址加载到AX
	mov	ds, ax                         ! 设置数据段地址为0x1000
	xor	ax, ax                         ! 清空AX寄存器
	mov	es, ax                         ! 设置附加段地址为0x0000
	mov	cx, #0x2000                    ! 设置拷贝字节数为0x2000（8KB）
	sub	si,si                          ! 清空SI寄存器，ds:si=0x1000:0000
	sub	di,di                          ! 清空DI寄存器，es:di=0x0000:0000
	rep                                ! 重复执行下一条指令
	movw                               ! 将ds:si指向的0x2000字节数据拷贝到es:di指向的0x0000:0000空间
	mov	ax, #BOOTSEG                   ! 重新设置数据段地址
	mov	ds, ax                         ! 设置数据段地址为0x07c0
	lidt	idt_48	                   ! 加载中断描述符表寄存器IDTR
	lgdt	gdt_48	                   ! 加载全局描述符表寄存器GDTR

! 切换到保护模式
	mov	ax,#0x0001                     ! 设置AX为0x0001
	lmsw	ax	                       ! 设置CR0寄存器的PE位（保护模式使能位），进入保护模式
	jmpi	0,8	                       ! 跳转至偏移地址0，段选择子8，使用代码段描述符

! 全局描述符表GDT
gdt:	.word	0,0,0,0	               ! 空描述符（索引0）
    ! 代码段描述符（索引1）
	.word	0x07FF	                   ! 8MB - 界限=2047（2048*4096=8MB）
	.word	0x0000	                   ! 基地址=0x00000
	.word	0x9A00	                   ! 代码段，可读/可执行，DPL=0，存在
	.word	0x00C0	                   ! 粒度=4096字节，32位模式
    ! 数据段描述符（索引2）
	.word	0x07FF	                   ! 8MB - 界限=2047（2048*4096=8MB）
	.word	0x0000	                   ! 基地址=0x00000
	.word	0x9200	                   ! 数据段，可读/可写，DPL=0，存在
	.word	0x00C0	                   ! 粒度=4096字节，32位模式

! 中断描述符表操作数
idt_48: .word	0	                   ! 中断描述符表长度为0（未使用）
	.word	0,0	                       ! 中断描述符表基地址为0
! 全局描述符表操作数
gdt_48: .word	0x7ff	               ! GDT表长度为2048字节
	.word	0x7c00+gdt,0	           ! GDT表基地址为0x7c00+gdt
.org 510                               ! 定位到第510字节
	.word   0xAA55                     ! 引导扇区标志（魔数）

