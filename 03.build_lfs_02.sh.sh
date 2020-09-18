#!/bin/bash
set -x

touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664 /var/log/lastlog
chmod -v 600 /var/log/btmp

cd /sources/build/

###
(
    cd /lib64
    ln /tools/lib64/ld-2.25.so ld-linux-x86-64.so.2

    # 需要观察后续这个库是否被重新覆盖！
)
###

# 6.7. Linux-4.9.9 API Headers
# tar -xvf /sources/linux-4.9.9.tar.xz
(
    cd linux-4.9.9/
    make mrproper
    make INSTALL_HDR_PATH=dest headers_install
    find dest/include \( -name .install -o -name ..install.cmd \) -delete
    cp -rv dest/include/* /usr/include
)
# pkg-config 编译报错！！！
# tar -xvf /sources/pkg-config-0.29.1.tar.gz
# (
#     cd pkg-config-0.29.1/
#     CFLAGS="-Werror=format-nonliteral"
#     ./configure --prefix=/usr --with-internal-glib
# )

# # 6.8. Man-pages-4.09 依赖上一个pkg-config!!!
# tar -xvf /sources/man-db-2.7.6.1.tar.xz
# (
#     cd man-db-2.7.6.1/
#     make install
# )

# 6.9. Glibc-2.25
# tar -xvf /sources/glibc-2.25.tar.xz
(
    cd glibc-2.25/
    make distclean
    patch -Np1 -i ../../glibc-2.25-fhs-1.patch
    case $(uname -m) in
        x86) ln -s ld-linux.so.2 /lib/ld-lsb.so.3
        ;;
        x86_64) ln -s ../lib/ld-linux-x86-64.so.2 /lib64
        ln -s ../lib/ld-linux-x86-64.so.2 /lib64/ld-lsb-x86-64.so.3
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
)


# 5.8. Libstdc++-6.3.0
# # tar -xvf /sources/gcc-6.3.0.tar.bz2
(
    cd gcc-6.3.0/
	cd build
	make distclean
    ../libstdc++-v3/configure \
        --host=$LFS_TGT \
        --prefix=/tools \
        --disable-multilib \
        --disable-nls \
        --disable-libstdcxx-threads \
        --disable-libstdcxx-pch \
        --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/6.3.0
    make -j12
    make install
)
# rm -fr gcc-6.3.0


##############################
# 利用编译出来的gcc6.3.0进行编译 #
#############################

CC=$LFS_TGT-gcc
CXX=$LFS_TGT-g++
AR=$LFS_TGT-ar
RANLIB=$LFS_TGT-ranlib

# 5.9. Binutils-2.27 - Pass 2
# 利用编译出来的gcc6.3.0编译binutils
# tar -xvf /sources/binutils-2.27.tar.bz2
(
    cd binutils-2.27/
    mkdir -v build
    cd build    
    RANLIB=$LFS_TGT-ranlib
    ../configure --prefix=/tools --disable-nls --disable-werror --with-lib-path=/tools/lib --with-sysroot
    make -j12
    make install
    make -C ld clean
    make -C ld LIB_PATH=/usr/lib:/lib
    cp -v ld/ld-new /tools/bin
)
# rm -fr binutils-2.27/

# 5.10. GCC-6.3.0 - Pass 2
# 利用编译出来的gcc 6.3.0 重新编译gcc-6.3.0，并覆盖安装
# glibc libstdc++包含在 gcc 6.3.0中
rm -fr gcc-6.3.0/
# tar -xvf /sources/gcc-6.3.0.tar.bz2
(
    cd gcc-6.3.0/
    # GCC now requires the GMP, MPFR and MPC packages
    # tar -xf /sources/mpfr-3.1.5.tar.xz
    mv -v mpfr-3.1.5 mpfr
    # tar -xf /sources/gmp-6.1.2.tar.xz
    mv -v gmp-6.1.2 gmp
    # tar -xf /sources/mpc-1.0.3.tar.gz
    mv -v mpc-1.0.3 mpc

    cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
    `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include-fixed/limits.h

    for file in gcc/config/{linux,i386/linux{,64}}.h
    do
        cp -uv $file{,.orig}
        sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
        -e 's@/usr@/tools@g' $file.orig > $file
        echo '
        #undef STANDARD_STARTFILE_PREFIX_1
        #undef STANDARD_STARTFILE_PREFIX_2
        #define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
        #define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
        touch $file.orig
    done

    case $(uname -m) in
        x86_64)
        sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
    ;;
    esac

    rm -rf build
    mkdir -v build
    cd build

   
    ../configure --prefix=/tools --with-local-prefix=/tools --with-native-system-header-dir=/tools/include --enable-languages=c,c++ --disable-libstdcxx-pch --disable-multilib --disable-bootstrap --disable-libgomp
    make -j12
    make install 
    ln -svf gcc /tools/bin/cc
)
# rm -fr gcc-6.3.0/

# 此后所有软件均采用重新编译出来的gcc6.3.0编译

# 5.11. Tcl-core-8.6.6
# tar -xvf /sources/tcl-core8.6.6-src.tar.gz
(
    cd tcl8.6.6/unix
    ./configure --prefix=/tools
    make -j12
#    TZ=UTC make test
    make install
    chmod -v u+w /tools/lib/libtcl8.6.so
    make install-private-headers
    ln -sv tclsh8.6 /tools/bin/tclsh
)
# rm -fr tcl8.6.6/

# 5.12. Expect-5.45
# tar -xvf /sources/expect5.45.tar.gz
(
    cd expect5.45/
    cp -v configure{,.orig}
    sed 's:/usr/local/bin:/bin:' configure.orig > configure
    ./configure --prefix=/tools \
        --with-tcl=/tools/lib \
        --with-tclinclude=/tools/include
    make -j12
    make test
    make SCRIPTS="" install
)
# rm -fr expect5.45/

# 5.13. DejaGNU-1.6
# tar -xvf /sources/dejagnu-1.6.tar.gz
(
    cd dejagnu-1.6/
    ./configure --prefix=/tools
    make -j12
    make install
    #    make check
)
# rm -fr dejagnu-1.6/

# 5.14. Check-0.11.0
# tar -xvf /sources/check-0.11.0.tar.gz
(
    cd check-0.11.0/
    PKG_CONFIG= ./configure --prefix=/tools
    make -j12
    #    make check
    make install 
)
# rm -fr check-0.11.0/


# 5.15. Ncurses-6.0
# tar -xvf /sources/ncurses-6.0.tar.gz
(
    cd ncurses-6.0/
    gawk --version
    sed -i s/mawk// configure
    ./configure --prefix=/tools \
        --with-shared \
        --without-debug \
        --without-ada \
        --enable-widec \
        --enable-overwrite
    make -j12
    make install
)
# rm -fr ncurses-6.0/


# 5.16. Bash-4.4
# tar -xvf /sources/bash-4.4.tar.gz
(
    cd bash-4.4/
    ./configure --prefix=/tools --without-bash-malloc
    make -j12
    # make test
    make install
    ln -sv bash /tools/bin/sh
)
# rm -fr bash-4.4/

# 5.17. Bison-3.0.4
# tar -xvf /sources/bison-3.0.4.tar.xz
(
    cd bison-3.0.4/
    ./configure --prefix=/tools
    make -j12
    # make check
    make install
)
# rm -fr bison-3.0.4/

# 5.18. Bzip2-1.0.6
# tar -xvf /sources/bzip2-1.0.6.tar.gz
(
    cd bzip2-1.0.6/
    make -j12
    make PREFIX=/tools install
)
# rm -fr bzip2-1.0.6/

# 5.19. Coreutils-8.26
# tar -xvf /sources/coreutils-8.26.tar.xz
(
    cd coreutils-8.26/
    export FORCE_UNSAFE_CONFIGURE=1
    ./configure --prefix=/tools --enable-install-program=hostname
    make -j12
    # make RUN_EXPENSIVE_TESTS=yes check
    make install 
)
# rm -fr coreutils-8.26/

# 5.20. Diffutils-3.5
# tar -xvf /sources/diffutils-3.5.tar.xz
(
    cd diffutils-3.5/
    ./configure --prefix=/tools
    make -j12
    # make check
    make install
)
# rm -fr diffutils-3.5/


# 5.21. File-5.30
# tar -xvf /sources/file-5.30.tar.gz
(
    cd file-5.30/
    ./configure --prefix=/tools
    make -j12
    # make check
    make install
)
# rm -fr file-5.30/

# 5.22. Findutils-4.6.0
# tar -xvf /sources/findutils-4.6.0.tar.gz
(
    cd findutils-4.6.0/
    ./configure --prefix=/tools
    make -j12
    # make check
    make install    
)
# rm -fr findutils-4.6.0/

# 5.23. Gawk-4.1.4
# tar -xvf /sources/gawk-4.1.4.tar.xz
(
    cd gawk-4.1.4/
    ./configure --prefix=/tools
    make -j12
    # make check
    make install    
)
# rm -fr gawk-4.1.4/


# 5.24. Gettext-0.19.8.1
# tar -xvf /sources/gettext-0.19.8.1.tar.xz
(
    cd gettext-0.19.8.1/gettext-tools/
    EMACS="no" ./configure --prefix=/tools --disable-shared
    make -C gnulib-lib -j12
    make -C intl pluralx.c -j12
    make -C src msgfmt -j12
    make -C src msgmerge -j12
    make -C src xgettext -j12
    cp -v src/{msgfmt,msgmerge,xgettext} /tools/bin
)
# rm -fr gettext-0.19.8.1/

# 5.25. Grep-3.0
# tar -xvf /sources/grep-3.0.tar.xz
(
    cd grep-3.0/
    ./configure --prefix=/tools
    make -j12
    # make check
    make install    
)
# rm -fr grep-3.0/

# 5.26. Gzip-1.8
# tar -xvf /sources/gzip-1.8.tar.xz
(
    cd gzip-1.8/
    ./configure --prefix=/tools
    make -j12
    # make check
    make install    
)
# rm -fr gzip-1.8/

# 5.27. M4-1.4.18
# tar -xvf /sources/m4-1.4.18.tar.xz
(
    cd m4-1.4.18/
    ./configure --prefix=/tools
    make -j12
    # make check
    make install    
)
# rm -fr m4-1.4.18/

# 5.28. Make-4.2.1
# tar -xvf /sources/make-4.2.1.tar.bz2
(
    cd make-4.2.1/
    ./configure --prefix=/tools --without-guile
    make -j12
    # make check
    make install    
)
# rm -fr make-4.2.1/

# 5.29. Patch-2.7.5
# tar -xvf /sources/patch-2.7.5.tar.xz
(
    cd patch-2.7.5/
    ./configure --prefix=/tools
    make -j12
    # make check
    make install    
)
# rm -fr patch-2.7.5/

# 5.30. Perl-5.24.1
# tar -xvf /sources/perl-5.24.1.tar.bz2
(
    cd perl-5.24.1/
    sh Configure -des -Dprefix=/tools -Dlibs=-lm
    make -j12
    cp -v perl cpan/podlators/scripts/pod2man /tools/bin
    mkdir -pv /tools/lib/perl5/5.24.1
    cp -Rv lib/* /tools/lib/perl5/5.24.1
)
# rm -fr perl-5.24.1/

# 5.31. Sed-4.4
# tar -xvf /sources/sed-4.4.tar.xz
(
    cd sed-4.4/
    ./configure --prefix=/tools
    make -j12
    # make check
    make install    
)
# rm -fr sed-4.4/

# 5.32. Tar-1.29
# tar -xvf /sources/tar-1.29.tar.xz
(
    cd tar-1.29/
    export FORCE_UNSAFE_CONFIGURE=1
    ./configure --prefix=/tools
    make -j12
    # make check
    make install    
)
# rm -fr tar-1.29/

# 5.33. Texinfo-6.3
# tar -xvf /sources/texinfo-6.3.tar.xz
(
    cd texinfo-6.3/
    ./configure --prefix=/tools
    make -j12
    # make check
    make install
)
# rm -fr texinfo-6.3/

# 5.34. Util-linux-2.29.1
# tar -xvf /sources/util-linux-2.29.1.tar.xz
(
    cd util-linux-2.29.1/
    ./configure --prefix=/tools --without-python --disable-makeinstall-chown --without-systemdsystemunitdir --enable-libmount-force-mountinfo PKG_CONFIG=""    
    make
    make install
)
# rm -fr util-linux-2.29.1/

# 5.35. Xz-5.2.3
# tar -xvf /sources/xz-5.2.3.tar.xz
(
    cd xz-5.2.3/
    ./configure --prefix=/tools
    make -j12
    # make check
    make install
)

