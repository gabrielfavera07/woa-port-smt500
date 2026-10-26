#!/bin/bash
set -e
PKG=/root/Mu-Silicium/Platforms/Samsung/gta4lPkg
rm -rf /PwrCtlQuiesceDxe
mkdir -p "$PKG/PwrCtlQuiesceDxe"
cp /mnt/e/VIBECODING/windroid10/woa-port-smt500/driver-b2/PwrCtlQuiesce.c "$PKG/PwrCtlQuiesceDxe/"
cp /mnt/e/VIBECODING/windroid10/woa-port-smt500/driver-b2/PwrCtlQuiesce.inf "$PKG/PwrCtlQuiesceDxe/"
grep -q PwrCtlQuiesce "$PKG/gta4l.dsc" || sed -i 's|^  gta4l/AcpiTables.inf|  gta4l/AcpiTables.inf\n  gta4lPkg/PwrCtlQuiesceDxe/PwrCtlQuiesce.inf|' "$PKG/gta4l.dsc"
grep -q PwrCtlQuiesce "$PKG/gta4l.fdf" || sed -i 's|INF RuleOverride = ACPITABLE gta4l/AcpiTables.inf|INF RuleOverride = ACPITABLE gta4l/AcpiTables.inf\n  INF gta4lPkg/PwrCtlQuiesceDxe/PwrCtlQuiesce.inf|' "$PKG/gta4l.fdf"
grep -n PwrCtlQuiesce "$PKG/gta4l.dsc" "$PKG/gta4l.fdf"
echo INSTALL-OK
