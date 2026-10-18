#!/bin/sh

# Look for any factory.ubi in /tmp
FACTORY=$(ls /tmp/*factory.ubi 2>/dev/null | head -n 1)

if [ -z "$FACTORY" ] || [ ! -f "$FACTORY" ]; then
    echo "[-] Error: factory.ubi not found in /tmp!"
    exit 1
fi
echo "[+] Found factory image: $FACTORY"

# Detect active and idle slots
ACT=$(grep -oE 'ubi\.mtd=[^ ]+' /proc/cmdline | cut -d= -f2)
echo "[+] Active slot is: $ACT"

if [ "$ACT" = "rootfs" ]; then
    IDLE="rootfs_1"
else
    IDLE="rootfs"
fi
echo "[+] Idle slot is: $IDLE"

# Find MTD device and number
DEV=$(grep "\"$IDLE\"" /proc/mtd | cut -d: -f1)
NUM=$(echo "$DEV" | tr -dc '0-9')
echo "[+] Target MTD device: /dev/$DEV ($NUM)"

# Get offset and size in hex
OFF=$(printf "0x%x" $(cat /sys/class/mtd/$DEV/offset))
SIZ=$(printf "0x%x" $(cat /sys/class/mtd/$DEV/size))
echo "[+] Offset: $OFF, Size: $SIZ"

# Flash the factory image
echo "[+] Formatting and flashing $FACTORY to /dev/$DEV..."
ubidetach -m "$NUM" 2>/dev/null || true
ubiformat "/dev/$DEV" -y -f "$FACTORY"

# Configure U-Boot
echo "[+] Updating U-Boot environment..."
fw_setenv mtdids 'nand0=nand0'
fw_setenv mtdparts "mtdparts=nand0:${SIZ}@${OFF}(${IDLE})"
fw_setenv bootcmd "ubi detach; ubi part ${IDLE}; ubi read 0x46000000 kernel; bootm 0x46000000"

echo "[+] SUCCESS! Rebooting in 3 seconds..."
sleep 3
reboot