# Troubleshooting

Common issues and their solutions when flashing OpenWrt on the Jio AX6000 (JIDU6J11).

---

## ⚠️ Router Soft-Bricked After Flashing (No Boot / Kernel Panic)

**Cause:** You used the wrong factory image. The OpenWrt build produces two different files that end in `factory.ubi`:

| File | Type | Works with `flash.sh`? |
| :--- | :--- | :--- |
| `*-initramfs-factory.ubi` | Initramfs (kernel + rootfs in RAM) | ✅ **YES — use this one** |
| `*-squashfs-factory.ubi` | SquashFS (kernel + rootfs on NAND) | ❌ **NO — causes soft brick** |

The `squashfs-factory.ubi` requires `bootargs` to tell the kernel where to find its rootfs on NAND. Our `flash.sh` only sets `bootcmd` (not `bootargs`), because the initramfs image carries its rootfs in RAM and doesn't need them.

**If you flashed `squashfs-factory.ubi`:** The kernel boots but can't find its rootfs → kernel panic → no network → soft brick.

### Recovery

If you backed up `mfg.bin` (Step 1.4 of the README), you can recover via UART:

1. Open the router and connect a USB-UART adapter to the serial header
2. Use your U-Boot credentials from `mfg.bin` to access the U-Boot console
3. Reset the boot environment:
   ```
   env default -a
   saveenv
   reset
   ```
4. The router will boot back into stock Jio firmware
5. Re-do the flashing process using the correct `*-initramfs-factory.ubi` image

> 💡 **This is why backing up `mfg.bin` is critical** — it contains your UART login password needed for recovery.

---

## SSH Connection Issues

### `ssh: Connection refused` or `Connection timed out`

**Cause:** SSH is not enabled on the stock router.

**Fix:** Complete [Step 1: Enable SSH](../README.md#step-1-enable-ssh-on-stock-firmware). Make sure you enter all three passwords in order:
1. `Aa1$(passwd${IFS}-d${IFS}root)`
2. `Cc2$(killall${IFS}dropbear)`
3. `Dd3$(dropbear${IFS}-B)`

> If the router was rebooted after enabling SSH, you'll need to repeat Step 1 — the SSH exploit does not persist across reboots on stock firmware.

---

### `Host key verification failed`

```
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
```

**Cause:** The router's SSH host key has changed (expected — the key changes when switching between stock and OpenWrt).

**Fix:** Remove the old key:
```bash
ssh-keygen -R 192.168.31.1    # For stock firmware
ssh-keygen -R 192.168.1.1     # For OpenWrt
```

Then retry your SSH/SCP command.

---

### `Permission denied (publickey)`

**Cause:** The SSH daemon is not running with blank-password authentication.

**Fix:** Re-enter the third password in the WebUI:
```
Dd3$(dropbear${IFS}-B)
```

---

### `[-] Error: factory.ubi not found in /tmp!`

**Cause:** The factory UBI image wasn't uploaded to the router, or it was uploaded to the wrong path.

**Fix:** Ensure the SCP command completed successfully:
```bash
# Upload whichever variant you downloaded (Standard or Smallbuffers)
scp -O openwrt-qualcommbe-*-factory.ubi root@192.168.31.1:/tmp/
```

Check that the file exists on the router:
```bash
ssh root@192.168.31.1 "ls -la /tmp/*factory.ubi"
```

---

### Script errors like `illegal option` or `unexpected end of file`

**Cause:** Windows line endings (`\r\n`) in the shell script. This happens because Windows editors add carriage return characters that Linux can't handle.

**Fix:** Run this before executing the script:
```bash
sed -i 's/\r$//' /tmp/flash.sh
```

The automated `.bat` flasher does this automatically.

---

### `ubiformat` hangs or fails

**Cause:** The UBI device is still attached.

**Fix:** Detach it first:
```bash
# Find the MTD number from flash.sh output
ubidetach -m <MTD_NUMBER>

# Then retry
ubiformat /dev/mtd<NUMBER> -y -f /tmp/*factory.ubi
```

---

## Network / IP Issues

### Can't ping `192.168.1.1` after first flash

**Cause:** The router hasn't finished booting yet, or your PC hasn't obtained a new IP.

**Fix:**
1. **Wait longer** — the first boot can take up to 2-3 minutes
2. **Check your PC's IP** — it should now be in the `192.168.1.x` range:
   ```bash
   ipconfig
   ```
   If not, try:
   ```bash
   ipconfig /release
   ipconfig /renew
   ```
3. If using a static IP, temporarily set it to `192.168.1.2` with subnet `255.255.255.0`

---

### SCP fails with `Connection refused` during sysupgrade upload

**Cause:** You're trying to connect too soon after the router rebooted into temporary OpenWrt. The SSH service might not be ready yet.

**Fix:** Wait an extra 10-20 seconds after the router starts responding to ping, then retry.

---

## Sysupgrade Issues

### `Command failed: ubus call system sysupgrade ... (Connection failed)`

**This is expected behavior!** The sysupgrade command terminates your SSH session as it shuts down all services to perform the flash. The message "Connection failed" simply means the SSH connection was closed as part of the upgrade process.

**This is NOT an error.** Wait 90 seconds and the router will reboot into permanent OpenWrt.

---

### Router doesn't come back after sysupgrade

1. **Wait at least 3 minutes** — The sysupgrade process involves formatting NAND, writing images, and a full reboot
2. **Try pinging:**
   ```bash
   ping 192.168.1.1
   ```
3. **Check your Ethernet connection** — make sure the cable is firmly plugged in
4. If after 5 minutes there's still no response:
   - Try power cycling the router (unplug, wait 10 seconds, plug back in)
   - Wait another 2-3 minutes for it to boot

---

## After Install

### LuCI WebUI not loading

**Cause:** Browser DNS cache pointing to old router IP.

**Fix:**
1. Clear browser cache or try incognito mode
2. Try a different browser
3. Access directly: `http://192.168.1.1`
4. Verify via SSH that the router is up:
   ```bash
   ssh root@192.168.1.1
   ```

---

### `opkg install` fails with "No space left on device"

**Cause:** The overlay filesystem is full.

**Check available space:**
```bash
df -h /overlay
```

**Fix:** Remove unused packages:
```bash
opkg remove <package-name>
```

---

## Still Stuck?

If your issue isn't listed here:

1. Open an [Issue](../../issues) on this GitHub repository
2. Include:
   - The exact error message
   - Which step you were on
   - The output of `cat /proc/mtd` if you can access the router
   - Your router's model number (should be JIDU6J11)
