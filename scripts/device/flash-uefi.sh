#!/system/bin/sh
# flash-uefi.sh — roda NO TABLET via TWRP. Grava o payload UEFI (boot.img v2 com edk2)
# no slot 'boot' — o método deste aparelho (Samsung: sem fastboot; ABL aceita boot.img
# não assinado com bootloader destravado).
# Uso: adb push flash-uefi.sh /tmp/f.sh && adb shell sh /tmp/f.sh /external_sd/boot-uefi.img
set -e
UEFI="${1:?uso: sh flash-uefi.sh <caminho/do/boot-uefi.img>}"
BOOT=/dev/block/by-name/boot
# guarda SEMPRE o boot atual antes de gravar (restaurável para voltar ao Android)
dd if=$BOOT of=/external_sd/boot-android-backup.img bs=4194304 2>/dev/null
echo "[ok] boot atual salvo em /external_sd/boot-android-backup.img"
dd if="$UEFI" of=$BOOT bs=4194304
echo "[ok] UEFI gravado no slot boot. reboot = boot Windows (se esp/win prontas)."
echo "     Para voltar ao Android: sh restore-android-boot.sh"
