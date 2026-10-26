#!/bin/bash
# Auditoria SHA1 dos UUPs contra manifest.tsv
M=/mnt/e/VIBECODING/windroid10/woa-port-smt500/image-work/uup/manifest.tsv
U=/mnt/e/VIBECODING/windroid10/woa-port-smt500/image-work/uup/UUPs
while IFS=$'\t' read -r name sha1 size url; do
  [ -f "$U/$name" ] || { echo "FALTANDO: $name"; continue; }
  got=$(sha1sum "$U/$name" | cut -d' ' -f1)
  if [ "$got" = "$sha1" ]; then echo "OK: $name"; else echo "CORROMPIDO: $name (esperado $sha1, obtido $got)"; fi
done < "$M"
echo AUDIT-FIM
