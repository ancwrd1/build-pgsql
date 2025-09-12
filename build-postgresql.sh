#!/bin/bash

if [ "$1" == "" -o "$2" == "" ]; then
	echo "usage: $0 triple version"
	exit 1
fi

triple=$1
version=$2

case $triple in
	x86_64-*linux*)
		arch=x86_64
		;;
	aarch64-*linux*)
		arch=aarch64
		;;
	s390x-*linux*)
		arch=s390x
		;;
	arm-*linux*)
		arch=armv7l
		;;
	*)
		echo "unsupported target"
		exit 1
		;;
esac

basedir=$(dirname $(readlink -f $0))

openssl_version="3.5.2"
openssl_tar="openssl-$openssl_version.tar.gz"
libedit_tar="libedit-20250104-3.1.tar.gz"
postgresql_tar="postgresql-$version.tar.bz2"
ncurses_tar="ncurses.tar.gz"

# dependencies
deps="$basedir/deps/$triple"
mkdir -p "$deps"

# postgres dist
dist="$basedir/dist/$triple"
mkdir -p "$dist"

# build
build="$basedir/build/$triple"
mkdir -p "$build"

# cache for tarballs
cache="$basedir/cache"
mkdir -p "$cache"

# $1=archive, $2=url
download() {
	if [ -f "$cache/$1" ]; then
		echo "Found $1 in the cache"
	else
		echo "Downloading $1"
		if ! curl -L --output-dir "$cache" -O "$2"; then
			echo "Unable to download $1!"
			exit 1
		fi
	fi
}

download_postgresql() {
	download $postgresql_tar "https://ftp.postgresql.org/pub/source/v${version}/$postgresql_tar"
}

download_openssl() {
	download "$openssl_tar" "https://github.com/openssl/openssl/releases/download/openssl-$openssl_version/$openssl_tar"
}

download_libedit() {
	download $libedit_tar "https://thrysoee.dk/editline/$libedit_tar"
}

download_ncurses() {
	download $ncurses_tar "https://invisible-island.net/datafiles/release/$ncurses_tar"
}

build_openssl() {
	log="$build/openssl.log"
	rm -f "$log"
	echo "Building openssl"
	cd "$build"
	rm -rf openssl
	mkdir -p openssl
	tar xf "$cache/$openssl_tar" -C openssl --strip-components 1
	cd openssl
	if [ -z "$CC" ]; then
		cross=--cross-compile-prefix="$triple-"
	else
		cross=--cross-compile-prefix=
	fi
	case $arch in
		s390x)
			target=linux64-$arch
			;;
		*)
			target=linux-$arch
			;;
	esac
	./Configure --prefix=/usr "$cross" --libdir=lib no-shared no-threads $target >>"$log" 2>>"$log"
	if ! make -j8 >>"$log" 2>>"$log"; then
		echo "Build failed!"
		exit 1
	fi
	if ! make DESTDIR="$deps" install >>"$log" 2>>"$log"; then
		echo "Install failed!"
		exit 1
	fi
}

build_ncurses() {
	log="$build/ncurses.log"
	rm -f "$log"
	echo "Building ncurses"
	cd "$build"
	rm -rf ncurses
	mkdir -p ncurses
	tar xf "$cache/$ncurses_tar" -C ncurses --strip-components 1
	cd ncurses

	if ! ./configure --without-tests --with-install-prefix="$deps" --libdir=/usr/lib --prefix=/usr --host=$triple --disable-shared --disable-stripping --with-terminfo-dirs=/etc/terminfo:/lib/terminfo:/usr/share/terminfo >>$log 2>>$log; then
		echo "Configure failed!"
		exit 1
	fi

	if ! make -j8 >>$log 2>>$log; then
		echo "Build failed!"
		exit 1
	fi

	if ! make install >>"$log" 2>>"$log"; then
		echo "Install failed!"
		exit 1
	fi
}

build_libedit() {
	log="$build/libedit.log"
	rm -f "$log"
	echo "Building libedit"
	cd "$build"
	rm -rf libedit
	mkdir -p libedit
	tar xf "$cache/$libedit_tar" -C libedit --strip-components 1
	cd libedit

	LDFLAGS="-L$deps/usr/lib" CFLAGS="-I$deps/usr/include" ./configure  --libdir=/usr/lib --prefix=/usr --host=$triple --disable-shared >>"$log" 2>>"$log"
	if [ "$?" != "0" ]; then
		echo "Configure failed!"
		exit 1
	fi

	if ! make -j8 >>$log 2>>$log; then
		echo "Build failed!"
		exit 1
	fi

	if ! make DESTDIR="$deps" install >>"$log" 2>>"$log"; then
		echo "Install failed!"
		exit 1
	fi
}

check_build_deps() {
	echo "Checking and building dependencies"

	if [ -f "$deps/usr/lib/libcrypto.a" ]; then
		echo "Using existing openssl"
	else
		download_openssl
		build_openssl
	fi

	if [ -f "$deps/usr/lib/libcurses.a" ]; then
		echo "Using existing ncurses"
	else
		download_ncurses
		build_ncurses
	fi

	if [ -f "$deps/usr/lib/libedit.a" ]; then
		echo "Using existing libedit"
	else
		download_libedit
		build_libedit
	fi
}

build_postgresql() {
	log="$build/postgresql.log"
	rm -f "$log"
	echo "Building postgresql"
	cd "$build"
	rm -rf postgresql
	mkdir -p postgresql
	tar xf "$cache/$postgresql_tar" -C postgresql --strip-components 1
	cd postgresql

	export LDFLAGS="-L$deps/usr/lib -Wl,-rpath=\\$\$ORIGIN/../lib"
	export LDFLAGS_EX="$LDFLAGS"
	export CFLAGS="-I$deps/usr/include"

	if ! ./configure --host=$triple --libdir=/usr/lib --prefix=/usr --with-openssl --without-zlib --without-icu >>"$log" 2>>"$log"; then
		echo "Configure failed!"
		exit 1
	fi

	if ! make -j8 >>$log 2>>$log; then
		echo "Build failed!"
		exit 1
	fi

	rm -rf "$dist"
	if ! make DESTDIR="$dist" install >>"$log" 2>>"$log"; then
		echo "Install failed!"
		exit 1
	fi
}

package_postgresql() {
	echo "Packaging postgresql"
	cd "$dist"
	mv usr pgsql
	rm -rf pgsql/include
	strip pgsql/bin/*
	find pgsql -name \*.so\* -exec strip {} \;
	find pgsql -name \*.a -exec rm -f {} \;
	tar cJf pgsql-$version-linux-$arch.tar.xz pgsql
}

check_build_deps
download_postgresql
build_postgresql
package_postgresql
