# buildLFS

问题1
```
chroot "$LFS" /tools/bin/env -i \
> HOME=/root \
> TERM="$TERM" \
> PS1='\u:\w\$ ' \
> PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin \
> /tools/bin/bash --login +h
chroot: failed to run command ‘/tools/bin/env’: No such file or directory
[root@localhost lfs]# ll
total 28
drwxr-xr-x.  20 root root  3100 2020-09-10 20:44:34 dev
drwx------.   2 root root 16384 2020-09-09 04:52:50 lost+found
dr-xr-xr-x. 159 root root     0 2020-09-10 20:44:35 proc
drwxrwxrwt.   2 root root    40 2020-09-11 01:59:38 run
drwxrwxrwt.   3 lfs  root  4096 2020-09-10 04:28:19 sources
dr-xr-xr-x.  13 root root     0 2020-09-10 20:44:32 sys
drwxr-xr-x.  10 root root  4096 2020-09-11 01:56:16 tools
drwxr-xr-x.   2 root root  4096 2020-09-09 23:29:46 usr

```
原书步骤，到目前为止， usr目录都是空的，/目录下没有lib lib64 bin等目录


问题2： gcc安装后，没有安装基础lib到lib64目录！且编译的是gcc6,当前系统用的是gcc4

拷贝当前系统内的基础库到$LFS/tools/lib64
```
cd $LFS/tools/lib64
cp /lib64/libdl.so.2 .
cp /lib64/libc.so.6 .
cp /lib64/ld-linux-x86-64.so.2 .
```

作软链接，完善/目录结构
