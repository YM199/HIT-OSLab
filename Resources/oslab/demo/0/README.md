# 引导扇区编译命令

;编译引导扇区程序的完整步骤

as86 -0 -a -o boot.o boot.s    ;使用as86汇编器编译boot.s文件
                               ; -0: 生成16位代码（实模式）
                               ; -a: 生成汇编列表文件
                               ; -o boot.o: 输出目标文件为boot.o

ld86 -0 -s -o boot boot.o      ;使用ld86链接器链接目标文件
                               ; -0: 生成16位可执行文件
                               ; -s: 去除符号表，减小文件大小
                               ; -o boot: 输出可执行文件为boot

dd bs=1 if=boot of=Image skip=32  ;使用dd命令处理可执行文件
                                  ; bs=1: 块大小为1字节
                                  ; if=boot: 输入文件为boot
                                  ; of=Image: 输出文件为Image
                                  ; skip=32: 跳过前32字节（Minix头部）
                                  ; 这样得到纯二进制代码，可以直接作为引导扇区使用

cp Image ../linux-0.11/Image