#!/sbin/sh
# Aplica Windows 11 22621 ARM64 na particao win (p83) a partir do TWRP.
# Requisitos em /data: install.esd, wimlib-imagex (ARM64 estatico), Unattend.xml
set -e
W=/data/wimlib-imagex
ESD=/data/install.esd
WIN=/dev/block/by-name/win

echo "== wimlib no TWRP:"
$W --version

echo "== injetando Unattend.xml na imagem 1 (panther)"
$W update $ESD 1 --command="add /data/Unattend.xml /Windows/Panther/Unattend.xml"

echo "== aplicando imagem 1 direto na particao NTFS (varios minutos)"
$W apply $ESD 1 NTFS:$WIN --no-acls --no-attributes

echo "== restaurando ESP de junho"
mkdir -p /esp
mount -t vfat /dev/block/by-name/esp /esp
rm -rf /esp/EFI/Microsoft /esp/EFI/Boot /esp/startup.bak
mv /esp/EFI/Microsoft.off /esp/EFI/Microsoft
mv /esp/EFI/Boot.off /esp/EFI/Boot
umount /esp

echo "== DONE — reboot para testar (firmware v7 no boot)"
