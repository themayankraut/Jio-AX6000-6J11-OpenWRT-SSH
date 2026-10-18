# How It Works — Technical Deep Dive

This document explains the complete technical details behind the SSH-based OpenWrt installation on the Jio AX6000 (JIDU6J11). If you just want to flash the device, see the [main README](../README.md).

---

## Table of Contents

- [Device Overview](#device-overview)
- [Stock NAND Partition Layout](#stock-nand-partition-layout)
- [The Dual-Boot Slot System](#the-dual-boot-slot-system)
- [Why MTD Numbers Vary Between Units](#why-mtd-numbers-vary-between-units)
- [The SSH Exploit (Command Injection)](#the-ssh-exploit-command-injection)
- [Phase 1: Factory Image Flash](#phase-1-factory-image-flash)
  - [How the Factory Image is Built](#how-the-factory-image-is-built)
  - [Slot Detection Logic](#slot-detection-logic)
  - [U-Boot Environment Manipulation](#u-boot-environment-manipulation)
- [Phase 2: Sysupgrade (Permanent Install)](#phase-2-sysupgrade-permanent-install)
  - [Partition Merging](#partition-merging)
  - [What Sysupgrade Actually Does](#what-sysupgrade-actually-does)
- [Why Stock Firmware Cannot Be Restored](#why-stock-firmware-cannot-be-restored)
- [Memory Map and Load Addresses](#memory-map-and-load-addresses)

---

## Device Overview

| Spec | Details |
| :--- | :--- |
| **Model** | Jio AX6000 (JIDU6J11) |
| **SoC** | Qualcomm IPQ50xx |
| **NAND Flash** | 256 MB raw NAND |
| **RAM** | 512 MB DDR |
| **Bootloader** | U-Boot |
| **Stock OS** | Custom Jio Linux (BusyBox-based) |

---

## Stock NAND Partition Layout

The stock firmware divides the 256 MB NAND into many MTD partitions. The key ones for our purposes:

```
/proc/mtd (stock firmware — example from one unit):
dev:    size   erasesize  name
mtd0:  ...    ...        "0:SBL1"
mtd1:  ...    ...        "0:MIBIB"
...
mtd22: ...    ...        "0:WIFIFW_1"
mtd23: 05000000 00020000 "rootfs_1"     ← 80 MB
mtd24: 05000000 00020000 "rootfs"       ← 80 MB
...
```

> **Important:** The MTD numbering (mtd23 vs mtd24) and which one is `rootfs` vs `rootfs_1` can be **swapped** between units. See below.

---

## The Dual-Boot Slot System

The Jio firmware uses an **A/B dual-boot** scheme:

- **Slot A:** `rootfs`
- **Slot B:** `rootfs_1`

At any time, one slot is **active** (currently booted) and the other is **idle** (available for OTA updates). The active slot is indicated in the kernel command line:

```bash
# Check which slot is active:
cat /proc/cmdline
# Look for: ubi.mtd=rootfs  or  ubi.mtd=rootfs_1
```

When Jio pushes an OTA update, it writes the new firmware to the **idle** slot and switches the boot target. This is the same mechanism we exploit — we write OpenWrt to the idle slot.

---

## Why MTD Numbers Vary Between Units

You might see different people reporting different MTD numbers:

| Unit | Active Slot | Active MTD | Idle Slot | Idle MTD | Idle Offset |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Unit A** | `rootfs` | mtd24 | `rootfs_1` | mtd23 | `0x1700000` |
| **Unit B** | `rootfs` | mtd23 | `rootfs_1` | mtd24 | `0x6700000` |

This happens because Jio's OTA updates swap the active/idle slots. A router that has received different OTA updates will have a different active slot assignment.

**This is why we never hardcode MTD numbers.** The `flash.sh` script dynamically reads:
- `/proc/cmdline` → to identify the active slot name
- `/proc/mtd` → to find the MTD device for the idle slot
- `/sys/class/mtd/mtdX/offset` → to get the NAND byte offset
- `/sys/class/mtd/mtdX/size` → to get the partition size

---

## The SSH Exploit (Command Injection)

The stock Jio WebUI has a password change form that passes user input to a shell command without proper sanitization. By entering specially crafted strings:

```
Aa1$(passwd${IFS}-d${IFS}root)     → Removes root password
Cc2$(killall${IFS}dropbear)        → Kills existing SSH daemon
Dd3$(dropbear${IFS}-B)             → Starts SSH with no-auth login
```

**How it works:**
- `Aa1` / `Cc2` / `Dd3` — Satisfy the WebUI's password complexity rules (must have uppercase, lowercase, digit)
- `$(...)` — Shell command substitution; the router executes the enclosed command
- `${IFS}` — Internal Field Separator (represents a space). Used because the form may strip literal space characters

After entering all three, the router has:
1. No root password
2. SSH daemon (dropbear) running with `-B` flag (allow blank password login)

---

## Phase 1: Factory Image Flash

### How the Factory Image is Built

The factory UBI image is created by wrapping the initramfs FIT image (`openwrt-...-initramfs-uImage.itb`) inside a UBI container. This image contains a single UBI volume named `kernel` which holds the **complete kernel + embedded rootfs in RAM**. Since the entire OS runs from RAM, no `bootargs` are needed — the kernel finds its rootfs automatically.

> ⚠️ **Do NOT use `*-squashfs-factory.ubi` with this flashing method.** The squashfs factory image requires additional `bootargs` configuration that `flash.sh` does not set, and will result in a **soft brick**.

It is generated using `ubinize`:

```ini
# ubinize.cfg
[kernel]
mode=ubi
image=openwrt-qualcommbe-ipq95xx-jiorouter_ax6000-jidu6j11-initramfs-uImage.itb
vol_id=0
vol_name=kernel
vol_type=dynamic
vol_alignment=1
vol_flags=autoresize
```

```bash
ubinize -o openwrt-qualcommbe-ipq95xx-jiorouter_ax6000-jidu6j11-initramfs-factory.ubi -m 2048 -p 128KiB -s 2048 ubinize.cfg
```

Parameters match the NAND geometry:
- `-m 2048` — Minimum I/O unit size (2 KiB pages)
- `-p 128KiB` — Physical erase block size
- `-s 2048` — Sub-page size

### Slot Detection Logic

The `flash.sh` script performs dynamic slot detection:

```bash
# 1. Read active slot from kernel command line
ACT=$(grep -oE 'ubi\.mtd=[^ ]+' /proc/cmdline | cut -d= -f2)
# Result: "rootfs" or "rootfs_1"

# 2. Determine idle slot (the opposite one)
if [ "$ACT" = "rootfs" ]; then
    IDLE="rootfs_1"
else
    IDLE="rootfs"
fi

# 3. Find the MTD device for the idle slot
DEV=$(grep "\"$IDLE\"" /proc/mtd | cut -d: -f1)
# Result: "mtd23" or "mtd24"

# 4. Get NAND offset and size
OFF=$(printf "0x%x" $(cat /sys/class/mtd/$DEV/offset))
SIZ=$(printf "0x%x" $(cat /sys/class/mtd/$DEV/size))
```

Then it flashes:

```bash
ubidetach -m "$NUM" 2>/dev/null || true   # Detach if already attached
ubiformat "/dev/$DEV" -y -f "$FACTORY"    # Format and write UBI image
```

### U-Boot Environment Manipulation

After flashing, we need to tell U-Boot to boot from the newly flashed idle slot. The stock U-Boot doesn't have `mtdids` or `mtdparts` set, so `ubi part <name>` would fail. We set them:

```bash
fw_setenv mtdids 'nand0=nand0'
fw_setenv mtdparts "mtdparts=nand0:${SIZ}@${OFF}(${IDLE})"
fw_setenv bootcmd "ubi detach; ubi part ${IDLE}; ubi read 0x46000000 kernel; bootm 0x46000000"
```

This tells U-Boot:
1. **`mtdids`**: Map NAND device `nand0` to the identifier `nand0`
2. **`mtdparts`**: Define a partition named after the idle slot at the correct offset and size
3. **`bootcmd`**: On boot, attach the UBI partition, read the `kernel` volume into RAM at `0x46000000`, and boot it

---

## Phase 2: Sysupgrade (Permanent Install)

### Partition Merging

The temporary OpenWrt (initramfs) runs entirely from RAM. When we apply `sysupgrade`, the OpenWrt `platform.sh` script for this device runs:

```bash
jiorouter_initial_setup() {
    # Only run in initramfs mode
    [ "$(rootfs_type)" = "tmpfs" ] || return 0

    # Reconfigure U-Boot to use a single large "ubi" partition
    fw_setenv mtdparts 'mtdparts=nand0:0xe100000@0x1700000(ubi)'
    fw_setenv bootcmd 'ubi part ubi; ubi read 0x44000000 kernel; bootm 0x44000000'
    fw_setenv bootargs 'console=ttyMSM0,115200n8 ubi.mtd=ubi root=/dev/ubiblock0_1 rootfstype=squashfs'
}
```

The key line:
```
mtdparts=nand0:0xe100000@0x1700000(ubi)
```

This defines a **single partition** starting at offset `0x1700000` with size `0xe100000` (~225 MB). This spans the **entire area** that was previously divided between `rootfs` and `rootfs_1`.

### What Sysupgrade Actually Does

The `sysupgrade` process (`nand_do_upgrade` → `nand_upgrade_tar`):

1. **Detaches** any existing UBI from the `ubi` partition
2. **Formats** the entire partition with `ubiformat`
3. **Attaches** the clean UBI partition
4. **Creates UBI volumes**:
   - `kernel` — Receives the kernel FIT image
   - `rootfs` — Receives the SquashFS root filesystem
   - `rootfs_data` — Takes all remaining space for the writable overlay
5. **Writes** the kernel and rootfs images to their respective volumes
6. **Reboots** into the permanent system

After this, the NAND layout becomes:

```
Before (stock):
  ┌──────────────┐┌──────────────┐
  │   rootfs     ││  rootfs_1    │   ← Two separate 80MB partitions
  │  (Jio FW)   ││  (empty/old) │
  └──────────────┘└──────────────┘

After (sysupgrade):
  ┌──────────────────────────────┐
  │         Single "ubi"         │   ← One ~225MB partition
  │  kernel │ rootfs │ rootfs_data│
  │  4.9MB  │ 11.5MB│   195.9MB  │
  └──────────────────────────────┘
```

---

## Why Stock Firmware Cannot Be Restored

After sysupgrade:

1. The **partition table** in U-Boot's environment has been changed from two separate partitions to one combined partition
2. The **NAND area** that held the stock firmware has been **formatted and overwritten** with OpenWrt's UBI volumes
3. There is **no recovery partition** or stock firmware backup on the device
4. Jio does not provide stock firmware images for manual re-flashing

The only way to recover stock (or unbrick via hardware/UART) is by using the credentials and partition data saved during [Step 1.4: Backup MFG Partition](../README.md#14-️-recommended-backup-mfg-partition--retrieve-u-boot-creds).

---

## Memory Map and Load Addresses

When U-Boot loads the kernel into RAM for booting:

| Address | Usage |
| :--- | :--- |
| `0x44000000` | Permanent OpenWrt kernel load address (used after sysupgrade) |
| `0x46000000` | Initramfs kernel load address (used during factory boot) |

The initramfs uses `0x46000000` instead of `0x44000000` to avoid overlapping with the kernel decompression space. The ~20 MB initramfs image at `0x44000000` would collide with where the kernel tries to decompress itself.
