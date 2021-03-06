#!/bin/bash
# run as root
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
umask 022
export LFS=/mnt/lfs
export LC_ALL=POSIX
export LFS_TGT=x86_64-lfs-linux-gnu
export PATH=/tools/bin:/bin:/usr/bin
export LFS LC_ALL LFS_TGT PATH


mkdir -pv $LFS
mkdir -pv $LFS/usr
mkdir -pv $LFS/tools
mkdir -pv $LFS/sources
# wget --input-file=wget-list --continue --directory-prefix=$LFS/sources
mkdir -v $LFS/tools
ln -sv $LFS/tools /



cd $LFS/sources
mkdir build
cd build

#######################
# 利用宿主服务gcc进行编译#
######################

# 5.4. Binutils-2.27 - Pass 1
tar -jxvf $LFS/sources/binutils-2.27.tar.bz2
(
    cd binutils-2.27/
    mkdir -v build    
    cd build
    ../configure --prefix=/tools \
        --with-sysroot=$LFS \
        --with-lib-path=/tools/lib \
        --target=$LFS_TGT \
        --disable-nls \
        --disable-werror    
    make -j12
 
    case $(uname -m) in
    x86_64) mkdir -v /tools/lib && ln -sv lib /tools/lib64 ;;
    esac
 
    make install    
)
# 5.5. GCC-6.3.0 - Pass 1
tar -jxvf $LFS/sources/gcc-6.3.0.tar.bz2
(
    cd gcc-6.3.0/
    # GCC now requires the GMP, MPFR and MPC packages
    tar -xf $LFS/sources/mpfr-3.1.5.tar.xz
    mv -v mpfr-3.1.5 mpfr
    tar -xf $LFS/sources/gmp-6.1.2.tar.xz
    mv -v gmp-6.1.2 gmp
    tar -xf $LFS/sources/mpc-1.0.3.tar.gz
    mv -v mpc-1.0.3 mpc
    # The following command will change the location of GCC's default dynamic linker to use the one installed in /tools.
    # It also removes /usr/include from GCC's include search path.
    for file in gcc/config/{linux,i386/linux{,64}}.h
        do
        cp -uvf $file{,.orig}
        sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
        -e 's@/usr@/tools@g' $file.orig > $file
        echo '
		#undef STANDARD_STARTFILE_PREFIX_1
        #undef STANDARD_STARTFILE_PREFIX_2
        #define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
        #define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
        touch $file.orig
    done

    # on x86_64 hosts, set the default directory name for 64-bit libraries to “lib”
    case $(uname -m) in
    x86_64)
    sed -e '/m64=/s/lib64/lib/' \
    -i.orig gcc/config/i386/t-linux64
    ;;
    esac

    mkdir -v build    
    cd build
	# export CFLAGS="-O2 -fpermissive"
	# export CXXFLAGS="-O2 -fpermissive"
    ../configure \
        --target=$LFS_TGT \
        --prefix=/tools \
        --with-glibc-version=2.11 \
        --with-sysroot=$LFS \
        --with-newlib \
        --without-headers \
        --with-local-prefix=/tools \
        --with-native-system-header-dir=/tools/include \
        --disable-nls \
        --disable-shared \
        --disable-multilib \
        --disable-decimal-float \
        --disable-threads \
        --disable-libatomic \
        --disable-libgomp \
        --disable-libmpx \
        --disable-libquadmath \
        --disable-libssp \
        --disable-libvtv \
        --disable-libstdcxx \
        --enable-languages=c,c++
    
    make -j12    
    make install    
)

# 5.6. Linux-4.9.9 API Headers
tar -xvf $LFS/sources/linux-4.9.9.tar.xz
(
    cd linux-4.9.9/
    make mrproper
    make INSTALL_HDR_PATH=dest headers_install
    cp -rvf dest/include/* /tools/include
)

##############################
# 利用编译出来的gcc6.3.0进行编译 #
#############################
# 比原文提前！

CC=$LFS_TGT-gcc
CXX=$LFS_TGT-g++
AR=$LFS_TGT-ar
RANLIB=$LFS_TGT-ranlib


# 5.7. Glibc-2.25
tar -xvf $LFS/sources/glibc-2.25.tar.xz
(
    cd glibc-2.25/
    mkdir -v build
    cd build
    ../configure \
        --prefix=/tools \
        --host=$LFS_TGT \
        --build=$(../scripts/config.guess) \
        --enable-kernel=2.6.32 \
        --with-headers=/tools/include \
        libc_cv_forced_unwind=yes \
        libc_cv_c_cleanup=yes 
    make -j12
    export PATH=/bin:/usr/bin:/tools/bin
    make install
    export PATH=/tools/bin:/bin:/usr/bin
)
rm -fr glibc-2.25/

# 5.8. Libstdc++-6.3.0
# tar -xvf $LFS/sources/gcc-6.3.0.tar.bz2
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




# 5.9. Binutils-2.27 - Pass 2
# 利用编译出来的gcc6.3.0编译binutils
rm -fr binutils-2.27/
tar -xvf $LFS/sources/binutils-2.27.tar.bz2
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
    cp -vf ld/ld-new /tools/bin
)

# 5.10. GCC-6.3.0 - Pass 2
# 利用编译出来的gcc 6.3.0 重新编译gcc-6.3.0，并覆盖安装
# glibc libstdc++包含在 gcc 6.3.0中
rm -fr gcc-6.3.0/
tar -xvf $LFS/sources/gcc-6.3.0.tar.bz2
(
    cd gcc-6.3.0/
    # GCC now requires the GMP, MPFR and MPC packages
    tar -xf $LFS/sources/mpfr-3.1.5.tar.xz
    mv -v mpfr-3.1.5 mpfr
    tar -xf $LFS/sources/gmp-6.1.2.tar.xz
    mv -v gmp-6.1.2 gmp
    tar -xf $LFS/sources/mpc-1.0.3.tar.gz
    mv -v mpc-1.0.3 mpc

    cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
    `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include-fixed/limits.h

    for file in gcc/config/{linux,i386/linux{,64}}.h
    do
        cp -uvf $file{,.orig}
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

# 此后所有软件均采用重新编译出来的gcc6.3.0编译

# 5.11. Tcl-core-8.6.6
tar -xvf $LFS/sources/tcl-core8.6.6-src.tar.gz
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

# 5.12. Expect-5.45
tar -xvf $LFS/sources/expect5.45.tar.gz
(
    cd expect5.45/
    cp -vf configure{,.orig}
    sed 's:/usr/local/bin:/bin:' configure.orig > configure
    ./configure --prefix=/tools \
        --with-tcl=/tools/lib \
        --with-tclinclude=/tools/include
    make -j12
    make test
    make SCRIPTS="" install
)

# 5.13. DejaGNU-1.6
tar -xvf $LFS/sources/dejagnu-1.6.tar.gz
(
    cd dejagnu-1.6/
    ./configure --prefix=/tools
    make -j12
    make install
    #    make check
)

# 5.14. Check-0.11.0
tar -xvf $LFS/sources/check-0.11.0.tar.gz
(
    cd check-0.11.0/
    PKG_CONFIG= ./configure --prefix=/tools
    make -j12
    #    make check
    make install 
)


# 5.15. Ncurses-6.0
tar -xvf $LFS/sources/ncurses-6.0.tar.gz
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


# 5.16. Bash-4.4
tar -xvf $LFS/sources/bash-4.4.tar.gz
(
    cd bash-4.4/
    ./configure --prefix=/tools --without-bash-malloc
    make -j12
    # make test
    make install
    ln -sv bash /tools/bin/sh
)

# 5.17. Bison-3.0.4
tar -xvf $LFS/sources/bison-3.0.4.tar.xz
(
    cd bison-3.0.4/
    ./configure --prefix=/tools
    make -j12
    # make check
    make install
)

# 5.18. Bzip2-1.0.6
tar -xvf $LFS/sources/bzip2-1.0.6.tar.gz
(
    cd bzip2-1.0.6/
    make -j12
    make PREFIX=/tools install
)

# 5.19. Coreutils-8.26
tar -xvf $LFS/sources/coreutils-8.26.tar.xz
(
    cd coreutils-8.26/
    export FORCE_UNSAFE_CONFIGURE=1
    ./configure --prefix=/tools --enable-install-program=hostname
    make -j12
    # make RUN_EXPENSIVE_TESTS=yes check
    make install 
)

# 5.20. Diffutils-3.5
tar -xvf $LFS/sources/diffutils-3.5.tar.xz
(
    cd diffutils-3.5/
    ./configure --prefix=/tools
    make -j12
    # make check
    make install
)


# 5.21. File-5.30
tar -xvf $LFS/sources/file-5.30.tar.gz
(
    cd file-5.30/
    ./configure --prefix=/tools
    make -j12
    # make check
    make install
)

# 5.22. Findutils-4.6.0
tar -xvf $LFS/sources/findutils-4.6.0.tar.gz
(
    cd findutils-4.6.0/
    ./configure --prefix=/tools
    make -j12
    # make check
    make install    
)

# 5.23. Gawk-4.1.4
tar -xvf $LFS/sources/gawk-4.1.4.tar.xz
(
    cd gawk-4.1.4/
    ./configure --prefix=/tools
    make -j12
    # make check
    make install    
)


# 5.24. Gettext-0.19.8.1
tar -xvf $LFS/sources/gettext-0.19.8.1.tar.xz
(
    cd gettext-0.19.8.1/gettext-tools/
    EMACS="no" ./configure --prefix=/tools --disable-shared
    make -C gnulib-lib -j12
    make -C intl pluralx.c -j12
    make -C src msgfmt -j12
    make -C src msgmerge -j12
    make -C src xgettext -j12
    cp -vf src/{msgfmt,msgmerge,xgettext} /tools/bin
)

# 5.25. Grep-3.0
tar -xvf $LFS/sources/grep-3.0.tar.xz
(
    cd grep-3.0/
    ./configure --prefix=/tools
    make -j12
    # make check
    make install    
)

# 5.26. Gzip-1.8
tar -xvf $LFS/sources/gzip-1.8.tar.xz
(
    cd gzip-1.8/
    ./configure --prefix=/tools
    make -j12
    # make check
    make install    
)

# 5.27. M4-1.4.18
tar -xvf $LFS/sources/m4-1.4.18.tar.xz
(
    cd m4-1.4.18/
    ./configure --prefix=/tools
    make -j12
    # make check
    make install    
)

# 5.28. Make-4.2.1
tar -xvf $LFS/sources/make-4.2.1.tar.bz2
(
    cd make-4.2.1/
    ./configure --prefix=/tools --without-guile
    make -j12
    # make check
    make install    
)

# 5.29. Patch-2.7.5
tar -xvf $LFS/sources/patch-2.7.5.tar.xz
(
    cd patch-2.7.5/
    ./configure --prefix=/tools
    make -j12
    # make check
    make install    
)

# 5.30. Perl-5.24.1
tar -xvf $LFS/sources/perl-5.24.1.tar.bz2
(
    cd perl-5.24.1/
    sh Configure -des -Dprefix=/tools -Dlibs=-lm
    make -j12
    cp -vf perl cpan/podlators/scripts/pod2man /tools/bin
    mkdir -pv /tools/lib/perl5/5.24.1
    cp -Rvf lib/* /tools/lib/perl5/5.24.1
)

# 5.31. Sed-4.4
tar -xvf $LFS/sources/sed-4.4.tar.xz
(
    cd sed-4.4/
    ./configure --prefix=/tools
    make -j12
    # make check
    make install    
)

# 5.32. Tar-1.29
tar -xvf $LFS/sources/tar-1.29.tar.xz
(
    cd tar-1.29/
    export FORCE_UNSAFE_CONFIGURE=1
    ./configure --prefix=/tools
    make -j12
    # make check
    make install    
)

# 5.33. Texinfo-6.3
tar -xvf $LFS/sources/texinfo-6.3.tar.xz
(
    cd texinfo-6.3/
    ./configure --prefix=/tools
    make -j12
    # make check
    make install
)

# 5.34. Util-linux-2.29.1
tar -xvf $LFS/sources/util-linux-2.29.1.tar.xz
(
    cd util-linux-2.29.1/
    ./configure --prefix=/tools --without-python --disable-makeinstall-chown --without-systemdsystemunitdir --enable-libmount-force-mountinfo PKG_CONFIG=""    
    make
    make install
)

# 5.35. Xz-5.2.3
tar -xvf $LFS/sources/xz-5.2.3.tar.xz
(
    cd xz-5.2.3/
    ./configure --prefix=/tools
    make -j12
    # make check
    make install
)

#  5.36. Stripping
strip --strip-debug /tools/lib/*
/usr/bin/strip --strip-unneeded /tools/{,s}bin/*
rm -rf /tools/{,share}/{info,man,doc}

# Changing Ownership
chown -R root:root $LFS/tools


