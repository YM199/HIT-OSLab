BOOSTSEG = 0x07c0
SYSSEG   = 0X1000
SYSLEN   = 17
entry start
start:
    jmpi go,#BOOSTSEG ;段间跳转到0x7c0:go处，cs = 0x07c0
go:
    mov ax,cs
    mov ds,ax
    mov ss,ax ;设置数据段（DS）和堆栈段（SS）与代码段（CS）相同
    mov sp,#0x400 ;设置栈底地址为0x8000

load_system:
    mov dx,#0x0000 ;磁头号
    mov cx,#0x0002 ;驱动器号
    mov ax,#SYSSEG
    mov es,ax ;设置附加段寄存器
    xor bx,bx ;清零bx
    mov ax,#0x200+SYSLEN
    int 0x13 ;执行磁盘读取（触发中断）加载到内存地址 ES:BX = 0x1000:0x0000 = 0x10000
    jnc ok_load ;读取成功
die:
    jmp die ;读取失败

ok_load:
    cli ;关闭所有中断，防止在模式切换时被中断干扰

    ;将系统内核从内存地址 0x10000 复制到 0x00000
    mov ax, #SYSSEG
    mov ds, ax
    xor ax, ax
    mov es, ax
    mov cx, #0x1000
    sub si,si
    sub di,di
    rep ;重复执行后面的指令CX次
    movw ;从DS:SI指向的内存读取一个字节写到ES:DI指向的内存

    mov ax, #BOOSTSEG
    mov ds, ax
    lidt idt_48 ;加载中断描述符表寄存器
    lgdt gdt_48 ;加载全局描述符表寄存器
    mov ax,#0x0001
    lmsw ax ;设置CR0的PE位为1，开启保护模式,后面运行都是保护模式了
    jmpi 0,8 ;段间跳转，段偏移为0，段选择子为8（对应段描述符1）
gdt:
    ;段描述符0
    .word 0,0,0,0 ;不用，占位

    ;段描述符1，代码段
    .word 0x07ff ;第1个字，段界限底16位
    .word 0x0000 ;第2个字，段基地址低16位
    .word 0x9a00 ;第3个字，段基地址高8位+段属性
    .word 0x00c0 ;第4个字，段界限高4位+段属性

    ;段描述符2，数据段
    .word = 0x07ff
    .word = 0x0000
    .word = 0x9200
    .word = 0x00c0
idt_48:
    .word 0 ;IDT界限0
    .word 0,0 ;IDT基地址0
gdt_48:
    .word 0x7ff ;GDT界限
    .word 0x7c00+gdt, 0 ;GDT基地址
.org 510
    .word 0xaa55
;最后一行要换行，不然编译报错
