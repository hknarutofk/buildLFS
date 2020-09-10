#!/bin/bash

# binutils 
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
rm -fr binutils-2.27/

# gcc
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

	# on x86_64 hosts, set the default directory name for 64-bit libraries to “lib”
	case $(uname -m) in
	x86_64)
	sed -e '/m64=/s/lib64/lib/' \
	-i.orig gcc/config/i386/t-linux64
	;;
	esac

	mkdir -v build    
	cd build
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
rm -fr gcc-6.3.0/

# tcl-core
tar -xvf $LFS/sources/tcl-core8.6.6-src.tar.gz
(
	cd tcl8.6.6/unix
	./configure --prefix=/tools
	make -j12
#	TZ=UTC make test
	make install
	chmod -v u+w /tools/lib/libtcl8.6.so
	make install-private-headers
	ln -sv tclsh8.6 /tools/bin/tclsh
)
rm -fr tcl8.6.6/

# expect
tar -xvf $LFS/sources/expect5.45.tar.gz
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
rm -fr expect5.45/

# DejaGNU
tar -xvf $LFS/sources/dejagnu-1.6.tar.gz
(
	cd dejagnu-1.6/
	./configure --prefix=/tools
	make -j12
	make install
	#	make check
)
rm -fr dejagnu-1.6/

# Check-0.11.0
tar -xvf $LFS/sources/check-0.11.0.tar.gz
(
	cd check-0.11.0/
	PKG_CONFIG= ./configure --prefix=/tools
	make -j12
	#	make check
	make install 
)
rm -fr check-0.11.0/


# Ncurses-6.0
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
rm -fr ncurses-6.0/


# Bash-4.4
tar -xvf $LFS/sources/bash-4.4.tar.gz
(
	cd bash-4.4/
	./configure --prefix=/tools --without-bash-malloc
	make -j12
	# make test
	make install
	ln -sv bash /tools/bin/sh
)
rm -fr bash-4.4/

# Bison-3.0.4
tar -xvf $LFS/sources/bison-3.0.4.tar.xz
(
	cd bison-3.0.4/
	./configure --prefix=/tools
	make -j12
	# make check
	make install
)
rm -fr bison-3.0.4/

# Bzip2-1.0.6
tar -xvf $LFS/sources/bzip2-1.0.6.tar.gz
(
	cd bzip2-1.0.6/
	make -j12
	make PREFIX=/tools install
)
rm -fr bzip2-1.0.6/

# Coreutils-8.26
tar -xvf $LFS/sources/coreutils-8.26.tar.xz
(
	cd coreutils-8.26/
	./configure --prefix=/tools --enable-install-program=hostname
	make -j12
	# make RUN_EXPENSIVE_TESTS=yes check
	make install 
)
rm -fr coreutils-8.26/

# Diffutils-3.5
tar -xvf $LFS/sources/diffutils-3.5.tar.xz
(
	cd diffutils-3.5/
	./configure --prefix=/tools
	make -j12
	# make check
	make install
)
rm -fr diffutils-3.5/


# File-5.30
tar -xvf $LFS/sources/file-5.30.tar.gz
(
	cd file-5.30/
	./configure --prefix=/tools
	make -j12
	# make check
	make install
)
rm -fr file-5.30/

# Findutils-4.6.0
tar -xvf $LFS/sources/findutils-4.6.0.tar.gz
(
	cd findutils-4.6.0/
	./configure --prefix=/tools
	make -j12
	# make check
	make install	
)
rm -fr findutils-4.6.0/

# Gawk-4.1.4
tar -xvf $LFS/sources/gawk-4.1.4.tar.xz
(
	cd gawk-4.1.4/
	./configure --prefix=/tools
	make -j12
	# make check
	make install	
)
rm -fr gawk-4.1.4/


# Gettext-0.19.8.1
tar -xvf $LFS/sources/gettext-0.19.8.1.tar.xz
(
	cd gettext-0.19.8.1/gettext-tools/
	EMACS="no" ./configure --prefix=/tools --disable-shared
	make -C gnulib-lib
	make -C intl pluralx.c
	make -C src msgfmt
	make -C src msgmerge
	make -C src xgettext
	cp -v src/{msgfmt,msgmerge,xgettext} /tools/bin
)
rm -fr gettext-0.19.8.1/
