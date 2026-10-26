#!/system/bin/sh
OUT=/tmp/collected
mkdir -p $OUT
s() { echo "===== $1 ====="; shift; "$@" 2>/dev/null || echo "[skip]"; }
echo "##### WOA-PORT DEVICE COLLECTION — SM-T500 gta4lwifi #####"
echo "## DATE: $(date)"
s "UNAME" uname -a
echo "===== GETPROP (key) ====="
for p in ro.product.name ro.product.model ro.product.device ro.board.platform ro.hardware ro.hardware.chipname ro.boot.hardware ro.boot.bootdevice ro.boot.serialno ro.vendor.qti.soc_name ro.soc.manufacturer ro.soc.model ro.arch; do echo "$p = $(getprop $p 2>/dev/null)"; done
echo "===== CPUINFO (head) ====="
head -40 /proc/cpuinfo 2>/dev/null
echo "===== CPU FREQ / CLUSTERS ====="
cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null
cat /sys/devices/system/cpu/cpu4/cpufreq/cpuinfo_max_freq 2>/dev/null
ls /sys/devices/system/cpu/ 2>/dev/null | grep -E 'cpu[0-9]+$'
echo "===== DT MODEL ====="
cat /sys/firmware/devicetree/base/model 2>/dev/null; echo
cat /proc/device-tree/compatible 2>/dev/null | tr '\0' ' '; echo
echo "===== MEMINFO (head) ====="
head -3 /proc/meminfo 2>/dev/null
echo "===== CMDLINE ====="
cat /proc/cmdline 2>/dev/null; echo
echo "===== PARTITIONS (proc) ====="
cat /proc/partitions 2>/dev/null
echo "===== BY-NAME MAP ====="
ls -l /dev/block/by-name/ 2>/dev/null || ls -l /dev/block/bootdevice/by-name/ 2>/dev/null
echo "===== BLOCK BASE DEV ====="
ls -l /dev/block/sda /dev/block/mmcblk0 2>/dev/null
readlink -f /dev/block/by-name/boot 2>/dev/null || readlink -f /dev/block/bootdevice/by-name/boot 2>/dev/null
echo "===== SCSI/UFS IDENTITY ====="
cat /sys/block/sda/device/vendor /sys/block/sda/device/model /sys/block/sda/device/rev 2>/dev/null
ls /sys/class/scsi_disk/ 2>/dev/null
cat /sys/kernel/debug/ufs/ufshcd0/device_desc 2>/dev/null | head -5
for f in /sys/devices/platform/*/ufshc*/string_descriptors/manufacturer_name /sys/devices/platform/*/ufshc*/string_descriptors/product_name; do cat $f 2>/dev/null && echo; done
echo "===== SDIO (WiFi likely) ====="
ls /sys/bus/sdio/devices/ 2>/dev/null
for d in /sys/bus/sdio/devices/*/; do echo -n "$d : "; cat $d/vendor 2>/dev/null | tr -d '\0'; echo -n ":"; cat $d/device 2>/dev/null | tr -d '\0'; echo; done
echo "===== I2C BUSES/DEVICES ====="
ls /sys/bus/i2c/devices/ 2>/dev/null
for d in /sys/bus/i2c/devices/i2c-*/; do echo -n "$d name: "; cat $d/name 2>/dev/null; done
for d in /sys/bus/i2c/devices/*/name; do echo -n "$d = "; cat $d 2>/dev/null; echo; done
echo "===== SPI DEVICES ====="
for d in /sys/bus/spi/devices/*/; do echo -n "$d modalias: "; cat $d/modalias 2>/dev/null; echo; done 2>/dev/null
echo "===== USB ====="
cat /sys/bus/usb/devices/*/idVendor 2>/dev/null | head -8
cat /sys/bus/usb/devices/*/idProduct 2>/dev/null | head -8
echo "===== POWER SUPPLY ====="
ls /sys/class/power_supply/ 2>/dev/null
for d in /sys/class/power_supply/*/; do echo -n "$d type="; cat $d/type 2>/dev/null | tr -d '\n'; echo -n " status="; cat $d/status 2>/dev/null | tr -d '\n'; echo; done
echo "===== GRAPHICS ====="
ls /sys/class/graphics/ 2>/dev/null
cat /sys/class/graphics/fb0/virtual_size 2>/dev/null
for m in /sys/class/graphics/fb0/modes; do cat $m 2>/dev/null; done
echo "===== SOUND ====="
cat /proc/asound/cards 2>/dev/null
echo "===== THERMAL/TSENS ====="
ls /sys/class/thermal/ 2>/dev/null | head -20
echo "===== GPIO CHIPS ====="
ls /sys/class/gpio/ 2>/dev/null | head -5
for d in /sys/bus/platform/devices/*pinctrl*/; do echo "$d"; done 2>/dev/null | head -10
echo "##### END COLLECTION #####"
