#!/bin/bash
set -x

touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664 /var/log/lastlog
chmod -v 600 /var/log/btmp

mkdir /sources/build/
cd /sources/build/

###
# 文中未提到，没有ld-linux-x86-64.so.2 /tools/bin/gcc无法启动
(
    cd /lib64
    ln -svf /tools/lib64/ld-linux-x86-64.so.2     
)
(
    cd /usr/lib
    ln -svf /tools/lib/crt1.o 
    ln -svf /tools/lib/crti.o 
    ln -svf /tools/lib/crtn.o 
    ln -svf /tools/lib/libc.so
    # 需要观察后续这个库是否被重新覆盖！
)
###

# 6.7. Linux-4.9.9 API Headers
tar -xvf /sources/linux-4.9.9.tar.xz
(
    cd linux-4.9.9/
    make mrproper
    make INSTALL_HDR_PATH=dest headers_install
    find dest/include \( -name .install -o -name ..install.cmd \) -delete
    cp -rv dest/include/* /usr/include


    # /tools/lib/gcc/x86_64-pc-linux-gnu/6.3.0/../../../../x86_64-pc-linux-gnu/bin/ld: cannot find crt1.o: No such file or directory
    # cd /usr/lib && ln -svf /tools/lib/crt1.o 

)
echo $?


# 6.9. Glibc-2.25
tar -xvf /sources/glibc-2.25.tar.xz
(
    cd glibc-2.25/
    make distclean
    patch -Np1 -i /sources/glibc-2.25-fhs-1.patch
    case $(uname -m) in
        x86) ln -s ld-linux.so.2 /lib/ld-lsb.so.3
        ;;
        x86_64) ln -s /lib/ld-linux-x86-64.so.2 /lib64
        ln -s /lib/ld-linux-x86-64.so.2 /lib64/ld-lsb-x86-64.so.3
        ;;
    esac
    mkdir -v build
    cd build
    ../configure --prefix=/usr --enable-kernel=2.6.32 --enable-obsolete-rpc --enable-stack-protector=strong libc_cv_slibdir=/lib
    make -j12
    touch /etc/ld.so.conf
    make install
    cp -v ../nscd/nscd.conf /etc/nscd.conf
    mkdir -pv /var/cache/nscd
    install -v -Dm644 ../nscd/nscd.tmpfiles /usr/lib/tmpfiles.d/nscd.conf
    install -v -Dm644 ../nscd/nscd.service /lib/systemd/system/nscd.service
    mkdir -pv /usr/lib/locale
    localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8
    localedef -i de_DE -f ISO-8859-1 de_DE
    localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
    localedef -i de_DE -f UTF-8 de_DE.UTF-8
    localedef -i en_GB -f UTF-8 en_GB.UTF-8
    localedef -i en_HK -f ISO-8859-1 en_HK
    localedef -i en_PH -f ISO-8859-1 en_PH
    localedef -i en_US -f ISO-8859-1 en_US
    localedef -i en_US -f UTF-8 en_US.UTF-8
    localedef -i es_MX -f ISO-8859-1 es_MX
    localedef -i fa_IR -f UTF-8 fa_IR
    localedef -i fr_FR -f ISO-8859-1 fr_FR
    localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
    localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
    localedef -i it_IT -f ISO-8859-1 it_IT
    localedef -i it_IT -f UTF-8 it_IT.UTF-8
    localedef -i ja_JP -f EUC-JP ja_JP
    localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R
    localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
    localedef -i tr_TR -f UTF-8 tr_TR.UTF-8
    localedef -i zh_CN -f GB18030 zh_CN.GB18030

    # glibc-2.25/localedata/SUPPORTED
    make localedata/install-locales
)
# Installed programs: catchsegv, gencat, getconf, getent, iconv, iconvconfig, ldconfig, ldd, lddlibc4, locale,localedef, makedb, mtrace, nscd, pldd, rpcgen, sln, sotruss, sprof, tzselect, xtrace, zdump,and zic
# Installed libraries: ld-2.25.so, libBrokenLocale.{a,so}, libSegFault.so, libanl.{a,so}, libc.{a,so},libc_nonshared.a, libcidn.so, libcrypt.{a,so}, libdl.{a,so}, libg.a, libieee.a, libm.{a,so}, libmcheck.a, libmemusage.so, libnsl.{a,so}, libnss_compat.so, libnss_dns.so,libnss_files.so, libnss_hesiod.so, libnss_nis.so, libnss_nisplus.so, libpthread.{a,so},libpthread_nonshared.a, libresolv.{a,so}, librpcsvc.a, librt.{a,so}, libthread_db.so, and libutil.{a,so}
# Installed directories: /usr/include/arpa, /usr/include/bits, /usr/include/gnu, /usr/include/net, /usr/include/netash, /usr/include/netatalk, /usr/include/netax25, /usr/include/neteconet, /usr/include/netinet, /usr/include/netipx, /usr/include/netiucv, /usr/include/netpacket, /usr/include/netrom, /usr/include/netrose, /usr/include/nfs, /usr/include/protocols, /usr/include/rpc, /usr/include/rpcsvc, /usr/include/sys, /usr/lib/audit, /usr/lib/gconv, /usr/lib/locale, /usr/libexec/getconf, /usr/share/i18n, /usr/share/zoneinfo, /var/cache/nscd, and /var/lib/nss_db


cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf
passwd: files
group: files
shadow: files
hosts: files dns
networks: files
protocols: files
services: files
ethers: files
rpc: files
# End /etc/nsswitch.conf
EOF

# 6.9.2.2. Adding time zone data
tar -xf /sources/tzdata2016j.tar.gz
ZONEINFO=/usr/share/zoneinfo
mkdir -pv $ZONEINFO/{posix,right}
for tz in etcetera southamerica northamerica europe africa antarctica asia australasia backward pacificnew systemv; do
zic -L /dev/null -d $ZONEINFO -y "sh yearistype.sh" ${tz}
zic -L /dev/null -d $ZONEINFO/posix -y "sh yearistype.sh" ${tz}
zic -L leapseconds -d $ZONEINFO/right -y "sh yearistype.sh" ${tz}
done
cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
zic -d $ZONEINFO -p America/New_York
unset ZONEINFO
ln -sfv /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

### pkg-config 构建依赖glibc
tar -xvf /sources/pkg-config-0.29.1.tar.gz
(
    cd pkg-config-0.29.1/
    patch -Np1 -i  /sources/001-glib-gdate-suppress-string-format-literal-warning.patch 
    ./configure --prefix=/usr --with-internal-glib
    make -j12
    make install
)

### 6.8 诺到此处，pkg-config构建之后
# 6.8. Man-pages-4.09 依赖上一个pkg-config!!!
# tar -xvf /sources/man-db-2.7.6.1.tar.xz
# (
#     cd man-db-2.7.6.1/
#     ./configure --prefix=/usr
#     # configure: error: Package requirements (libpipeline >= 1.4.0) were not met:
#     make -j12
#     make install
# )

# 6.10. Adjusting the Toolchain
mv -v /tools/bin/{ld,ld-old}
mv -v /tools/$(uname -m)-pc-linux-gnu/bin/{ld,ld-old}
mv -v /tools/bin/{ld-new,ld}
ln -sv /tools/bin/ld /tools/$(uname -m)-pc-linux-gnu/bin/ld


gcc -dumpspecs | sed -e 's@/tools@@g' \
    -e '/\*startfile_prefix_spec:/{n;s@.*@/usr/lib/ @}' \
    -e '/\*cpp:/{n;s@$@ -isystem /usr/include@}' > `dirname $(gcc --print-libgcc-file-name)`/specs

echo 'int main(){}' > dummy.c
cc dummy.c -v -Wl,--verbose &> dummy.log

readelf -l a.out | grep ': /lib'
grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log
grep -B1 '^ /usr/include' dummy.log
grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'
grep "/lib.*/libc.so.6 " dummy.log


# 6.11. Zlib-1.2.11
tar -xvf /sources/zlib-1.2.11.tar.xz
(
    cd zlib-1.2.11/
    ./configure --prefix=/usr
    make -j12
    make install
    mv -v /usr/lib/libz.so.* /lib
    ln -sfv ../../lib/$(readlink /usr/lib/libz.so) /usr/lib/libz.so
)
# Installed libraries: libz.{a,so}

###
# 解决file编译找不到libz.so.1 ???
tar -xvf /sources/zlib-1.2.11.tar.xz
(
    cd zlib-1.2.11/
    ./configure --prefix=/tools
    make -j12
    make install
    mv -v /usr/lib/libz.so.* /lib
    ln -sfv ../../lib/$(readlink /usr/lib/libz.so) /usr/lib/libz.so
)
# Installed libraries: libz.{a,so}
###

# 6.12. File-5.30
tar -xvf /sources/file-5.30.tar.gz
(
    cd file-5.30/
    ./configure --prefix=/usr
    make -j12
    # 编译时失败，找不到libz.so.1
    make install
)
# Installed programs: file
# Installed library: libmagic.so



# 6.13. Binutils-2.27
expect -c "spawn ls"

tar -xvf /sources/binutils-2.27.tar.bz2
(
    cd binutils-2.27/
    mkdir -v build
    cd build
    ../configure --prefix=/usr \
        --enable-gold \
        --enable-ld=default \
        --enable-plugins \
        --enable-shared \
        --disable-werror \
        --with-system-zlib
    # rm /usr/bin/ar ???
    make tooldir=/usr -j12
    make tooldir=/usr install
)
# Installed programs: addr2line, ar, as, c++filt, elfedit, gprof, ld, ld.bfd, nm, objcopy, objdump, ranlib, readelf,size, strings, and strip
# Installed libraries: libbfd.{a,so} and libopcodes.{a,so}
# Installed directory: /usr/lib/ldscripts




# 6.14. GMP-6.1.2
tar -xvf /sources/gmp-6.1.2.tar.xz
(
    cd gmp-6.1.2/
    ./configure --prefix=/usr \
        --enable-cxx \
        --disable-static \
        --docdir=/usr/share/doc/gmp-6.1.2
    make -j12
    make html -j12
    make install
    make install-html
)
# Installed Libraries: libgmp.so and libgmpxx.so
# Installed directory: /usr/share/doc/gmp-6.1.2

# 6.15. MPFR-3.1.5
tar -xvf /sources/mpfr-3.1.5.tar.xz
(
    cd mpfr-3.1.5/
    
)