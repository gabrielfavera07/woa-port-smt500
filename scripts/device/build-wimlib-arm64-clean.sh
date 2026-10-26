#!/bin/bash
# Rebuild completo em /mnt/c (fora do vhdx corrompido). Todas as correcoes inclusas.
set -ex
ROOTX=/mnt/c/woa-temp/xbuild
STAGE=$ROOTX/arm-stage
mkdir -p $ROOTX && cd $ROOTX

# --- libxml2 ---
[ -f libxml2-2.11.9.tar.xz ] || wget -q https://download.gnome.org/sources/libxml2/2.11/libxml2-2.11.9.tar.xz
[ -d libxml2-2.11.9 ] || tar xf libxml2-2.11.9.tar.xz
cd libxml2-2.11.9
./configure --host=aarch64-linux-gnu --prefix=$STAGE --without-python --without-zlib --without-lzma --without-http --without-ftp --without-iconv --disable-shared --enable-static
make -j"$(nproc)" && make install
cd $ROOTX

# --- ntfs-3g (tarball oficial Tuxera) ---
[ -f ntfs-3g_ntfsprogs-2022.10.3.tgz ] || wget -q -O ntfs-3g_ntfsprogs-2022.10.3.tgz https://tuxera.com/opensource/ntfs-3g_ntfsprogs-2022.10.3.tgz
[ -d ntfs-3g_ntfsprogs-2022.10.3 ] || tar xf ntfs-3g_ntfsprogs-2022.10.3.tgz
cd ntfs-3g_ntfsprogs-2022.10.3
./configure --host=aarch64-linux-gnu --prefix=$STAGE --disable-shared --enable-static --disable-mount --disable-ntfsprogs --without-uuid --without-libuuid CC=aarch64-linux-gnu-gcc
make -j"$(nproc)"
make install || true
# hook de install quebra em static-only; instalar lib na mao
cp -f libntfs-3g/.libs/libntfs-3g.a $STAGE/lib/
printf 'prefix=%s\nlibdir=%s/lib\nincludedir=%s/include\n\nName: ntfs-3g\nDescription: safe libntfs-3g library\nVersion: 2022.10.3\nLibs: -L${libdir} -lntfs-3g\nCflags: -I${includedir}\n' $STAGE $STAGE $STAGE > $STAGE/lib/pkgconfig/libntfs-3g.pc
ls -la $STAGE/lib/libntfs-3g.a
cd $ROOTX

# --- wimlib ---
[ -f wimlib-1.14.4.tar.gz ] || wget -q https://wimlib.net/downloads/wimlib-1.14.4.tar.gz
[ -d wimlib-1.14.4 ] || tar xf wimlib-1.14.4.tar.gz
cd wimlib-1.14.4
export PKG_CONFIG_PATH=$STAGE/lib/pkgconfig:$STAGE/share/pkgconfig
export CC=aarch64-linux-gnu-gcc
./configure --host=aarch64-linux-gnu --prefix=$STAGE --without-libcrypto --without-fuse --disable-shared --enable-static
make -j"$(nproc)" LDFLAGS="-static -s"
make install
file $STAGE/bin/wimlib-imagex
cp -f $STAGE/bin/wimlib-imagex /mnt/c/woa-temp/wimlib-imagex
ls -la /mnt/c/woa-temp/wimlib-imagex
echo BUILD-OK
