#!/bin/bash
# 6.2. Preparing Virtual Kernel File Systems
mkdir -pv $LFS/{dev,proc,sys,run}
# 6.2.1. Creating Initial Device Nodes
mknod -m 600 $LFS/dev/console c 5 1
mknod -m 666 $LFS/dev/null c 1 3
# 6.2.2. Mounting and Populating /dev
mount -v --bind /dev $LFS/dev
# 6.2.3. Mounting Virtual Kernel File Systems
mount -vt devpts devpts $LFS/dev/pts -o gid=5,mode=620
mount -vt proc proc $LFS/proc
mount -vt sysfs sysfs $LFS/sys
mount -vt tmpfs tmpfs $LFS/run
if [ -h $LFS/dev/shm ]; then
mkdir -pv $LFS/$(readlink $LFS/dev/shm)
fi


#文中未提到，chroot前配置lib lib64 bin目录，指向tools
####################################################
# cd $LFS
# mkdir usr/lib
# mkdir usr/lib64
# mkdir usr/bin

# ln -s usr/bin bin
# ln -s usr/lib lib
# ln -s usr/lib64 lib64

# (
# 	cd usr/lib64
# 	ls ../../tools/lib64/ | xargs -i ln -svf "../../tools/lib64/"{}
# )

####################################################


# 6.4. Entering the Chroot Environment
# by root user
chroot "$LFS" /tools/bin/env -i \
    HOME=/root \
    TERM="$TERM" \
    PS1='\u:\w\$ ' \
    PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin \
    /tools/bin/bash --login +h