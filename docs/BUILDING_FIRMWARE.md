# Building OpenWrt From Source

This guide explains how to compile the OpenWrt firmware for the Jio AX6000 (JIDU6J11) from source. Use this if you want to customize the firmware, add/remove packages, or use a newer OpenWrt version.

> **Not required for basic installation.** If you just want to install OpenWrt, download the pre-built images from the [Releases](../../releases) page.

---

## Prerequisites

### System Requirements

- **OS:** Ubuntu 22.04 / 24.04 (native or WSL2 on Windows)
- **Disk:** ~15 GB free space
- **RAM:** 8 GB minimum (16 GB recommended)
- **Internet:** Required to download sources and package feeds

### Install Build Dependencies (Ubuntu/Debian)

```bash
sudo apt update
sudo apt install -y build-essential clang flex bison g++ gawk \
  gcc-multilib g++-multilib gettext git libncurses5-dev libssl-dev \
  python3-distutils python3-setuptools rsync swig unzip zlib1g-dev \
  file wget
```

---

## Step 1: Clone OpenWrt

```bash
git clone https://git.openwrt.org/openwrt/openwrt.git
cd openwrt

# Checkout the desired release branch (e.g., v24.10 or main)
git checkout v24.10
```

---

## Step 2: Update Feeds

```bash
./scripts/feeds update -a
./scripts/feeds install -a
```

---

## Step 3: Configure for JIDU6J11

```bash
make menuconfig
```

Select the following:

| Option | Value |
| :--- | :--- |
| **Target System** | `Qualcomm Technologies, Inc. IPQ50xx/IPQ60xx/IPQ807x/IPQ95xx` |
| **Subtarget** | `Qualcomm IPQ50xx` |
| **Target Profile** | `Jio AX6000 (JIDU6J11)` |

### Recommended Packages

Under **LuCI** → **Collections**:
- `[*] luci` — Full LuCI web interface

Any additional packages you want can be selected here.

Save and exit.

---

## Step 4: Build

```bash
# First build (downloads toolchain, takes 1-2 hours)
make -j$(nproc) V=s

# Subsequent builds are much faster
```

> **Tip:** If the build fails, try `make -j1 V=s` for single-threaded build with verbose output to identify the error.

---

## Step 5: Locate Output Files

After a successful build, the firmware images are in:

```
bin/targets/qualcommbe/ipq95xx/
```

Key output files:

| File | Purpose |
| :--- | :--- |
| `openwrt-qualcommbe-ipq95xx-jiorouter_ax6000-jidu6j11-initramfs-uImage.itb` | Raw initramfs FIT image (kernel + embedded RAM rootfs) — **used to create factory UBI** |
| `openwrt-qualcommbe-ipq95xx-jiorouter_ax6000-jidu6j11-squashfs-sysupgrade.bin` | Permanent sysupgrade image (used in Step 2) |

> ⚠️ **The build also produces `*-squashfs-factory.ubi` — do NOT use it with this SSH flashing method.** It requires `bootargs` that `flash.sh` does not set, and will soft-brick the router.

---

## Step 6: Create the Factory UBI Image

Wrap the initramfs `.itb` into a UBI container using `ubinize`:

### Create `ubinize.cfg`:
```ini
[kernel]
mode=ubi
image=openwrt-qualcommbe-ipq95xx-jiorouter_ax6000-jidu6j11-initramfs-uImage.itb
vol_id=0
vol_name=kernel
vol_type=dynamic
vol_alignment=1
vol_flags=autoresize
```

### Run ubinize:
```bash
ubinize -o openwrt-qualcommbe-ipq95xx-jiorouter_ax6000-jidu6j11-initramfs-factory.ubi -m 2048 -p 128KiB -s 2048 ubinize.cfg
```

Parameters:
- `-m 2048` — Minimum I/O unit (NAND page size: 2 KiB)
- `-p 128KiB` — Physical eraseblock size
- `-s 2048` — Sub-page size

> 💡 For the **Small Buffers** variant, replace the filenames with the `*-smallbuffers-*` equivalents.

---

## Step 7: Flash

Copy the generated `*-initramfs-factory.ubi` and `*-sysupgrade.bin` files directly into your flasher folder alongside `Jio_6J11_OpenWrt_Flasher.bat` and `flash.sh`, then follow the instructions in the [main README](../README.md).

