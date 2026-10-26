#!/system/bin/sh
# backup-critical.sh — roda NO TABLET via TWRP (adb push + sh). Cópia das partições
# irrecuperáveis (identidade do aparelho) + boot/recovery atuais para /external_sd.
# Uso no PC:  adb push backup-critical.sh /tmp/b.sh && adb shell sh /tmp/b.sh
set -e
OUT=/external_sd/woa-backup-$(date +%Y%m%d-%H%M%S)
mkdir -p "$OUT"
for p in efs sec_efs persist modemst1 modemst2 fsg fsc modem blklog param dtbo boot recovery vbmeta vbmeta_samsung; do
  src=/dev/block/by-name/$p
  [ -e "$src" ] || { echo "[skip] $p (ausente)"; continue; }
  dd if="$src" of="$OUT/$p.img" bs=4194304 2>/dev/null
  echo "[ok] $p -> $OUT/$p.img ($(stat -c%s "$OUT/$p.img") bytes)"
done
# GPT primário e secundário
dd if=/dev/block/mmcblk0 of="$OUT/gpt-primary.bin" bs=512 count=34
SEC=$(cat /proc/partitions | awk '$3=="mmcblk0"{print int($2*1024/512)}')
dd if=/dev/block/mmcblk0 of="$OUT/gpt-backup.bin" bs=512 skip=$((SEC-33)) count=33
sha256sum "$OUT"/* > "$OUT/SHA256SUMS"
echo "BACKUP COMPLETO em $OUT — copie para o PC antes de prosseguir (adb pull)."
