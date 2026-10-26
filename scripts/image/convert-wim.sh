#!/bin/bash
echo "MARKER-CV10"
set -euo pipefail
UUP=/mnt/e/VIBECODING/windroid10/woa-port-smt500/image-work/uup/UUPs
WORK=/mnt/c/woa-temp
mkdir -p "$WORK/temp"
cd "$WORK"
rm -f install.wim winre.wim temp/*.ESD
rm -rf cabtmp

echo "== [1/5] Reference ESDs dos cabs (sem filtro update.mum)"
ok=0; fail=0
for cab in "$UUP"/*.cab; do
  name=$(basename "$cab" .cab)
  case "$name" in
    *RetailDemo*|*Holographic-Desktop-FOD*|*SSU-*) continue;;
  esac
  rm -rf "$WORK/cabtmp"; mkdir -p "$WORK/cabtmp"
  if ! 7z x -y -o"$WORK/cabtmp" "$cab" >/dev/null 2>&1; then
    echo "  7z-fail: $name"; fail=$((fail+1)); continue
  fi
  rm -f "$WORK/cabtmp/update.mum"
  if ! wimlib-imagex capture "$WORK/cabtmp" "temp/$name.ESD" --compress=XPRESS --check --no-acls --norpfix "Edition Package" "Edition Package" >/dev/null 2>&1; then
    echo "  cap-fail: $name"; fail=$((fail+1)); continue
  fi
  ok=$((ok+1))
done
echo "refs ok=$ok fail=$fail"

REFS=(--ref="$WORK/uupfix/*.ESD" --ref="$UUP/*.esd" --ref="$UUP/*.ESD" --ref="temp/*.ESD")

echo "== [2/5] export imagem 3"
wimlib-imagex export "$UUP/professional_pt-br.esd" 3 install.wim "${REFS[@]}" --compress=LZX "Windows 11 Pro" "Windows 11 Pro"

echo "== [3/5] export winre"
wimlib-imagex export "$UUP/professional_pt-br.esd" 2 winre.wim "${REFS[@]}" --compress=LZX --boot

echo "== [4/5] injeta winre + unattend"
wimlib-imagex update install.wim 1 <<'CMDS'
add /mnt/c/woa-temp/winre.wim /Windows/System32/Recovery/winre.wim
add /mnt/c/woa-temp/Unattend.xml /Windows/Panther/Unattend.xml
CMDS

echo "== [5/5] VERIFY COMPLETO"
wimlib-imagex verify install.wim
echo PIPELINE-OK
