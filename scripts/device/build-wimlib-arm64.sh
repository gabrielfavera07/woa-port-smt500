#!/bin/bash
set -ex
export DEBIAN_FRONTEND=noninteractive
mkdir -p /root/xbuild && cd /root/xbuild

# --- libxml2 (ja compilado na 1a rodada; pula se existir) ---
if [ ! -f /root/arm-stage/lib/libxml2.a ]; then
  apt-get update -qq
  apt-get install -y -qq gcc-aarch64-linux-gnu pkg-config make wget ca-certificates xz-utils file
  [ -f libxml2-2.11.9.tar.xz ] || wget -q https://download.gnome.org/sources/libxml2/2.11/libxml2-2.11.9.tar.xz
  tar xf libxml2-2.11.9.tar.xz
  cd libxml2-2.11.9
  ./configure --host=aarch64-linux-gnu --prefix=/root/arm-stage --without-python --without-zlib --without-lzma --without-http --without-ftp --without-iconv --disable-shared --enable-static
  make -j"$(nproc)" && make install
  cd /root/xbuild
fi

# --- ntfs-3g: tarball oficial Tuxera (tem configure pronto) ---
if [ ! -f /root/arm-stage/lib/libntfs-3g.a ]; then
  [ -f ntfs-3g_ntfsprogs-2022.10.3.tgz ] || wget -q -O ntfs-3g_ntfsprogs-2022.10.3.tgz https://tuxera.com/opensource/ntfs-3g_ntfsprogs-2022.10.3.tgz
  rm -rf ntfs-3g_ntfsprogs-2022.10.3
  tar xf ntfs-3g_ntfsprogs-2022.10.3.tgz
  cd ntfs-3g_ntfsprogs-2022.10.3
  ls configure
  ./configure --host=aarch64-linux-gnu --prefix=/root/arm-stage --disable-shared --enable-static --disable-mount --disable-ntfsprogs --without-uuid --without-libuuid CC=aarch64-linux-gnu-gcc
  make -j"$(nproc)" && make install
  cd /root/xbuild
fi

# --- wimlib estatico ---
export PKG_CONFIG_PATH=/root/arm-stage/lib/pkgconfig:/root/arm-stage/share/pkgconfig
export CC=aarch64-linux-gnu-gcc
cd /root/xbuild
[ -f wimlib-1.14.4.tar.gz ] || wget -q https://wimlib.net/downloads/wimlib-1.14.4.tar.gz
tar xf wimlib-1.14.4.tar.gz
cd wimlib-1.14.4
./configure --host=aarch64-linux-gnu --prefix=/root/arm-stage --without-libcrypto --without-fuse --disable-shared --enable-static
make -j"$(nproc)" LDFLAGS="-static -s"
make install
file /root/arm-stage/bin/wimlib-imagex
echo BUILD-OK
