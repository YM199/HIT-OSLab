#  head.s contains the 32-bit startup code.
#  Two L3 task multitasking. The code of tasks are in kernel area, 
#  just like the Linux. The kernel code is located at 0x10000. 

# 段选择子定义
SCRN_SEL	= 0x18                    # 屏幕段选择子（索引3）
TSS0_SEL	= 0x20                    # 任务状态段0选择子（索引4）
LDT0_SEL	= 0x28                    # 局部描述符表0选择子（索引5）
TSS1_SEL	= 0X30                    # 任务状态段1选择子（索引6）
LDT1_SEL	= 0x38                    # 局部描述符表1选择子（索引7）

.global startup_32                    # 声明全局符号startup_32
.text                                 # 代码段
startup_32:                           # 32位启动代码入口点
	movl $0x10,%eax                   # 将内核数据段选择子0x10加载到EAX
	mov %ax,%ds                       # 设置数据段寄存器DS为内核数据段
#	mov %ax,%es                       # 注释掉：设置附加段寄存器ES
	lss init_stack,%esp               # 设置栈指针ESP指向init_stack

# 设置中断描述符表IDT和全局描述符表GDT
	call setup_idt                    # 调用设置中断描述符表函数
	call setup_gdt                    # 调用设置全局描述符表函数
	movl $0x10,%eax                   # 重新加载内核数据段选择子
	mov %ax,%ds                       # 设置数据段寄存器DS
	mov %ax,%es                       # 设置附加段寄存器ES
	mov %ax,%fs                       # 设置FS段寄存器
	mov %ax,%gs                       # 设置GS段寄存器，所有段寄存器都指向内核数据段
	lss init_stack,%esp               # 重新设置栈指针

# 设置定时器8253芯片
	movb $0x36, %al                   # 设置8253控制字：模式3，二进制计数
	movl $0x43, %edx                  # 8253控制端口地址
	outb %al, %dx                     # 发送控制字到8253
	movl $11930, %eax                 # 设置定时器计数值11930，产生100Hz中断
	movl $0x40, %edx                  # 8253通道0数据端口地址
	outb %al, %dx                     # 发送低字节计数值
	movb %ah, %al                     # 准备发送高字节计数值
	outb %al, %dx                     # 发送高字节计数值

# 设置定时器和系统调用中断描述符
	movl $0x00080000, %eax            # 设置段选择子0x08（内核代码段）到EAX高16位
	movw $timer_interrupt, %ax        # 设置定时器中断处理程序偏移地址到EAX低16位
	movw $0x8E00, %dx                 # 设置描述符属性：中断门，DPL=0，存在
	movl $0x08, %ecx                  # 中断向量号8（对应IRQ0，定时器中断）
	lea idt(,%ecx,8), %esi            # 计算IDT表中第8个描述符的地址
	movl %eax,(%esi)                  # 设置描述符的低32位（段选择子+偏移低16位）
	movl %edx,4(%esi)                 # 设置描述符的高32位（属性+偏移高16位）
	movw $system_interrupt, %ax       # 设置系统调用中断处理程序偏移地址
	movw $0xef00, %dx                 # 设置描述符属性：陷阱门，DPL=3，存在
	movl $0x80, %ecx                  # 中断向量号128（对应系统调用中断）
	lea idt(,%ecx,8), %esi            # 计算IDT表中第128个描述符的地址
	movl %eax,(%esi)                  # 设置描述符的低32位
	movl %edx,4(%esi)                 # 设置描述符的高32位

# 注释掉：取消屏蔽定时器中断
#	movl $0x21, %edx                  # 8259A中断屏蔽寄存器地址
#	inb %dx, %al                      # 读取当前屏蔽位
#	andb $0xfe, %al                   # 清除第0位（定时器中断位）
#	outb %al, %dx                     # 写回屏蔽寄存器

# 切换到用户模式（任务0）
	pushfl                             # 将EFLAGS寄存器压栈
	andl $0xffffbfff, (%esp)           # 清除EFLAGS中的IF位（中断使能位）
	popfl                              # 将修改后的EFLAGS弹回寄存器
	movl $TSS0_SEL, %eax               # 设置TSS0的段选择子
	ltr %ax                            # 加载任务寄存器TR为TSS0
	movl $LDT0_SEL, %eax               # 设置LDT0的段选择子
	lldt %ax                           # 加载局部描述符表寄存器LDTR为LDT0
	movl $0, current                   # 设置当前任务为0
	sti                                # 设置中断使能位（开中断）
	pushl $0x17                        # 将用户数据段选择子压栈（SS）
	pushl $init_stack                  # 将用户栈地址压栈（ESP）
	pushfl                             # 将EFLAGS寄存器压栈
	pushl $0x0f                        # 将用户代码段选择子压栈（CS）
	pushl $task0                       # 将任务0的代码地址压栈（EIP）
	iret                               # 中断返回，切换到用户模式


setup_gdt:                             # 设置全局描述符表函数
	lgdt lgdt_opcode                   # 加载全局描述符表寄存器GDTR
	ret                                # 函数返回

# 将所有256个中断描述符都设置为指向默认的中断处理程序ignore_int
setup_idt:                             # 设置中断描述符表函数
	lea ignore_int,%edx                # 获取ignore_int函数的地址
	movl $0x00080000,%eax              # 设置段选择子0x08（内核代码段）到EAX高16位
	movw %dx,%ax                       # 将ignore_int偏移地址设置到EAX低16位
	movw $0x8E00,%dx                   # 设置描述符属性：中断门，DPL=0，存在
	lea idt,%edi                       # 获取IDT表的起始地址
	mov $256,%ecx                      # 设置循环计数器为256
rp_sidt:                               # 循环标签：重复设置中断描述符
	movl %eax,(%edi)                   # 将EAX的值写入IDT表（低32位）
	movl %edx,4(%edi)                  # 将EDX的值写入IDT表（高32位）
	addl $8,%edi                       # 移动到下一个描述符位置（每个描述符8字节）
	dec %ecx                           # 递减计数器
	jne rp_sidt                        # 如果计数器不为0，则继续循环
	lidt lidt_opcode                   # 加载中断描述符表寄存器IDTR
	ret                                # 函数返回


write_char:                            # 写字符到屏幕函数
	push %gs                           # 保存GS段寄存器
	pushl %ebx                         # 保存EBX寄存器
#	pushl %eax                         # 注释掉：保存EAX寄存器
	mov $SCRN_SEL, %ebx                # 设置屏幕段选择子0x18到EBX
	mov %bx, %gs                       # 将屏幕段选择子设置到GS段寄存器
	movl scr_loc, %ebx                 # 获取当前屏幕位置到EBX
	shl $1, %ebx                       # 将屏幕位置左移1位（每个字符占用2字节）
	movb %al, %gs:(%ebx)               # 将字符写入屏幕缓冲区
	shr $1, %ebx                       # 将屏幕位置右移1位，恢复原来的值
	incl %ebx                          # 位置加1，移动到下一个字符位置
	cmpl $2000, %ebx                   # 比较屏幕位置是否大于2000（80*25=2000）
	jb 1f                              # 如果屏幕位置小于2000，则跳转到标签1
	movl $0, %ebx                      # 如果屏幕位置大于2000，重置屏幕位置为0
1:	movl %ebx, scr_loc                 # 将屏幕位置保存到scr_loc
#	popl %eax                          # 注释掉：恢复EAX寄存器
	popl %ebx                          # 恢复EBX寄存器
	pop %gs                            # 恢复GS段寄存器
	ret                                # 函数返回

.align 2                               # 2字节对齐
ignore_int:                            # 默认中断处理程序
	push %ds                           # 保存DS段寄存器
	pushl %eax                         # 保存EAX寄存器
	movl $0x10, %eax                   # 设置内核数据段选择子
	mov %ax, %ds                       # 设置DS段寄存器
	movl $67, %eax                     # 设置字符'C'的ASCII码
	call write_char                    # 调用写字符函数
	popl %eax                          # 恢复EAX寄存器
	pop %ds                            # 恢复DS段寄存器
	iret                               # 中断返回


.align 2                               # 2字节对齐
timer_interrupt:                       # 定时器中断处理程序
	push %ds                           # 保存DS段寄存器
	pushl %eax                         # 保存EAX寄存器
	movl $0x10, %eax                   # 设置内核数据段选择子
	mov %ax, %ds                       # 设置DS段寄存器
	movb $0x20, %al                    # 设置EOI（中断结束）命令
	outb %al, $0x20                    # 发送EOI到8259A
	movl $1, %eax                      # 设置任务1的标识
	cmpl %eax, current                 # 比较当前任务是否为任务1
	je 1f                              # 如果是任务1，跳转到标签1
	movl %eax, current                 # 设置当前任务为任务1
	ljmp $TSS1_SEL, $0                 # 跳转到任务1
	jmp 2f                             # 跳转到标签2
1:	movl $0, current                   # 设置当前任务为任务0
	ljmp $TSS0_SEL, $0                 # 跳转到任务0
2:	popl %eax                          # 恢复EAX寄存器
	pop %ds                            # 恢复DS段寄存器
	iret                               # 中断返回


.align 2                               # 2字节对齐
system_interrupt:                      # 系统调用中断处理程序
	push %ds                           # 保存DS段寄存器
	pushl %edx                         # 保存EDX寄存器
	pushl %ecx                         # 保存ECX寄存器
	pushl %ebx                         # 保存EBX寄存器
	pushl %eax                         # 保存EAX寄存器
	movl $0x10, %edx                   # 设置内核数据段选择子
	mov %dx, %ds                       # 设置DS段寄存器
	call write_char                    # 调用写字符函数
	popl %eax                          # 恢复EAX寄存器
	popl %ebx                          # 恢复EBX寄存器
	popl %ecx                          # 恢复ECX寄存器
	popl %edx                          # 恢复EDX寄存器
	pop %ds                            # 恢复DS段寄存器
	iret                               # 中断返回


current:.long 0                        # 当前任务标识（0或1）
scr_loc:.long 0                        # 当前屏幕位置

.align 2                               # 2字节对齐
lidt_opcode:                           # IDT操作数
	.word 256*8-1                      # IDT表大小：256个描述符*8字节-1
	.long idt                          # IDT表基地址
lgdt_opcode:                           # GDT操作数
	.word (end_gdt-gdt)-1              # GDT表大小
	.long gdt                          # GDT表基地址

.align 8                               # 8字节对齐
idt:	.fill 256,8,0                   # IDT表：256个8字节描述符，初始化为0

gdt:                                   # 全局描述符表
	.quad 0x0000000000000000           # 空描述符（索引0）
	.quad 0x00c09a00000007ff           # 内核代码段（索引1）：基址0，界限0x7ff，代码段，可读
	.quad 0x00c09200000007ff           # 内核数据段（索引2）：基址0，界限0x7ff，数据段，可写
	.quad 0x00c0920b80000002           # 内核数据段，屏幕显示（索引3）：基址0xb8000，界限0x2

	.word 0x0068, tss0, 0xe900, 0x0    # 任务状态段TSS0（索引4）
	.word 0x0040, ldt0, 0xe200, 0x0    # 局部描述符表LDT0（索引5）
	.word 0x0068, tss1, 0xe900, 0x0    # 任务状态段TSS1（索引6）
	.word 0x0040, ldt1, 0xe200, 0x0    # 局部描述符表LDT1（索引7）
end_gdt:                               # GDT表结束
	.fill 128,4,0                      # 填充128个4字节的0
init_stack:                            # 用户栈
	.long init_stack                   # 栈指针
	.word 0x10                         # 栈段选择子


.align 8                               # 8字节对齐
ldt0:                                  # 局部描述符表0
    .quad 0x0000000000000000           # 空描述符
	.quad 0x00c0fa00000003ff           # 用户代码段：基址0，界限0x3ff，代码段，可读，DPL=3
	.quad 0x00c0f200000003ff           # 用户数据段：基址0，界限0x3ff，数据段，可写，DPL=3

# 任务状态段TSS0
tss0:                                  # 任务0的状态段
	.long 0                            # 无前一个任务
	.long krn_stk0, 0x10               # 内核栈0，栈段选择子0x10
	.long 0, 0, 0, 0, 0                # 特权级1-2的栈指针和段选择子（未使用）
	.long 0, 0, 0, 0, 0                # 继续填充未使用的栈信息
	.long 0, 0, 0, 0, 0                # 通用寄存器状态（EAX, ECX, EDX, EBX）
	.long 0, 0, 0, 0, 0, 0             # 段寄存器状态（ESP, EBP, ESI, EDI, ES, CS, SS, DS, FS, GS）
	.long LDT0_SEL, 0x8000000          # 局部描述符表LDT0，调试位图

	.fill 128,4,0                      # 填充128个4字节的0，为TSS0分配内核栈空间
krn_stk0:                              # 内核栈0起始位置
#	.long 0                            # 注释掉：栈底标记


.align 8                               # 8字节对齐
ldt1:	.quad 0x0000000000000000       # 局部描述符表1：空描述符
	.quad 0x00c0fa00000003ff           # 用户代码段：基址0x00000，界限0x3ff，DPL=3
	.quad 0x00c0f200000003ff           # 用户数据段：基址0x00000，界限0x3ff，DPL=3

tss1:	.long 0                        # 任务1的状态段：无前一个任务
	.long krn_stk1, 0x10               # 内核栈1，栈段选择子0x10
	.long 0, 0, 0, 0, 0                # 特权级1-2的栈指针和段选择子（未使用）
	.long task1, 0x200                 # EIP指向task1，EFLAGS=0x200（开中断）
	.long 0, 0, 0, 0                   # 通用寄存器状态（EAX, ECX, EDX, EBX）
	.long usr_stk1, 0, 0, 0            # 用户栈指针，其他寄存器为0
	.long 0x17,0x0f,0x17,0x17,0x17,0x17 # 段寄存器状态（ES, CS, SS, DS, FS, GS）
	.long LDT1_SEL, 0x8000000          # 局部描述符表LDT1，调试位图

	.fill 128,4,0                      # 填充128个4字节的0，为TSS1分配内核栈空间
krn_stk1:                              # 内核栈1起始位置


task0:                                 # 任务0代码
	movl $0x17, %eax                   # 设置用户数据段选择子0x17
	movw %ax, %ds                      # 设置DS段寄存器为用户数据段
	movb $65, %al                      # 设置字符'A'的ASCII码
	int $0x80                          # 执行系统调用（显示字符）
	movl $0xfff, %ecx                  # 设置循环计数器
1:	loop 1b                            # 循环延迟
	jmp task0                          # 跳转回task0开始，形成无限循环

task1:                                 # 任务1代码
	movl $0x17, %eax                   # 设置用户数据段选择子0x17
	movw %ax, %ds                      # 设置DS段寄存器为用户数据段
	movb $66, %al                      # 设置字符'B'的ASCII码
	int $0x80                          # 执行系统调用（显示字符）
	movl $0xfff, %ecx                  # 设置循环计数器
1:	loop 1b                            # 循环延迟
	jmp task1                          # 跳转回task1开始，形成无限循环

	.fill 128,4,0                      # 填充128个4字节的0，为用户栈1分配空间
usr_stk1:                              # 用户栈1起始位置
