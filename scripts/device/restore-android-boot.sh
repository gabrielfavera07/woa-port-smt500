#!/system/bin/sh
# restore-android-boot.sh — roda via TWRP. Restaura o boot.img Android salvo pelo
# flash-uefi.sh (dual-boot de volta ao LineageOS).
set -e
BK=/external_sd/boot-android-backup.img
[ -f "$BK" ] || { echo "backup nao encontrado: $BK"; exit 1; }
dd if="$BK" of=/dev/block/by-name/boot bs=4194304
echo "[ok] boot Android restaurado. reboot -> LineageOS."
