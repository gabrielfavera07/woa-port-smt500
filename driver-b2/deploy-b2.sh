#!/sbin/sh
# Deploy final do Windows com driver B2 — roda NO TABLET (TWRP).
# Requisitos em /data: install-w-drv.wim (com driver), wimlib-imagex, BCD novo.
set -e
W=/data/wimlib-imagex

echo "== formatando win"
mkfs.ntfs -f -L Windows /dev/block/by-name/win

echo "== aplicando imagem com driver (varios minutos)"
$W apply /data/install-w-drv.wim 1 /dev/block/by-name/win

echo "== BCD com testsigning"
mkdir -p /esp
mount -t vfat /dev/block/by-name/esp /esp
cp /data/BCD /esp/EFI/Microsoft/Boot/BCD
umount /esp

echo "== reboot para teste"
echo DEPLOY-B2-OK
