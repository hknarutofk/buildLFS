#!/bin/bash

# run as root

export LFS=/mnt/lfs
mkdir -pv $LFS
mkdir -pv $LFS/usr
mkdir -pv $LFS/tools
mkdir -pv $LFS/sources
wget --input-file=wget-list --continue --directory-prefix=$LFS/sources
mkdir -v $LFS/tools
ln -sv $LFS/tools /

# 4.3. Adding the LFS User
groupadd lfs
useradd -s /bin/bash -g lfs -m -k /dev/null lfs
chown -v lfs $LFS/tools
chown -v lfs $LFS/sources
su - lfs