文章参考：https://hoverwinter.gitbooks.io/hit-oslab-manual/content/environment.html

# 环境搭建

硬件环境：VMware + ubuntu-16.04.6-desktop-i386.iso

git clone https://github.com/YM199/HIT-OSLab



安装gcc编译器

```shell
tar zxvf gcc-3.4-ubuntu.tar.gz
cd gcc-3.4
sudo ./inst.sh xxxx #xxxx换为i386或amd64
```

安装一些工具

```bash
sudo apt-get install build-essential bin86 manpages-dev
```

# 使用方法

进入linux-0.11目录，然后执行`make all`，在oslab目录下执行`./run`，如果出现Bochs的窗口，里面显示linux的引导过程，最后停止在`[/usr/root/]#`，表示运行成功。

