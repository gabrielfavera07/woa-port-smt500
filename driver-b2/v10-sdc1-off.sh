#!/bin/bash
# v10: SDC1 _STA=0 — esconde o controlador do SO (bisect storage vs resto).
set -e
DSDT=/root/Mu-Silicium/Silicium-ACPI/Silicon/Qualcomm/Kamorta/DSDT.asl
if grep -q "SDC1 BISECT STA0" "$DSDT"; then
  echo "ja aplicado"
else
  sed -i 's|Name (_HID, "QCOM24BF")|Name (_HID, "QCOM24BF")\n            // SDC1 BISECT STA0: device oculto do SO\n            Method (_STA, 0, NotSerialized) { Return (0x0) }|' "$DSDT"
  grep -n -A2 "QCOM24BF" "$DSDT" | head -4
fi
echo PATCH-V10-OK
