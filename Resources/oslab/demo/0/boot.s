;引导扇区实现字符串显示
;这是一个简单的引导扇区程序，用于在屏幕上显示"Loading system ..."消息

BOOTSEG = 0x07c0        ;BIOS加载引导扇区的标准地址（0x7c00）

entry start              ;程序入口点声明
start:
        jmpi go,BOOTSEG  ;远跳转到BOOTSEG段，跳转到go标签处执行
                         ;jmpi是远跳转指令，会同时改变CS和IP寄存器
go:     mov ax,cs        ;将代码段寄存器CS的值复制到AX
        mov ds,ax        ;设置数据段寄存器DS = CS
        mov es,ax        ;设置附加段寄存器ES = CS
                         ;这样确保DS和ES都指向当前代码段，便于访问数据

        ;设置BIOS中断0x10功能13的参数（写字符串）
        mov cx,#19        ;CX = 字符串长度（19个字符）
        mov dx,#0x1004    ;DH = 10（显示位置行号），DL = 04（显示位置列号）
        mov bx,#0x000c    ;BH = 00（显示页号），BL = 0c（字符颜色属性，浅红色）
        mov bp,#msg1      ;BP = 字符串地址，指向msg1标签
        mov ax,#0x1301    ;AH = 13（BIOS功能号：写字符串），AL = 01（光标跟随移动）
        int 0x10          ;调用BIOS中断0x10，在屏幕上显示字符串

loop1:  jmp loop1         ;无限循环，程序执行完毕后停在这里
                         ;这是一个简单的死循环，防止程序继续执行到数据区域

msg1:   .ascii "Loading system ..."  ;定义要显示的字符串
        .byte 13,10       ;添加回车符(13)和换行符(10)，用于换行显示

.org 510                  ;汇编器指令：设置当前位置计数器到510字节
                         ;确保引导扇区的最后两个字节位于正确位置
        .word 0xAA55      ;引导扇区魔数，BIOS识别引导扇区的标准标识
                         ;在小端序系统中存储为：第510字节=0x55，第511字节=0xAA
