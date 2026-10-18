@echo off
setlocal enabledelayedexpansion
title Jio AX6000 (6J11) OpenWrt Auto-Flasher
color

echo =======================================================
echo     Jio AX6000 (6J11) - 1-Click OpenWrt Flasher
echo =======================================================
echo.

:: Detect factory image (Standard or SmallBuffers)
set "FACTORY="
if exist "*factory.ubi" (
    for %%f in (*factory.ubi) do (
        if not defined FACTORY set "FACTORY=%%f"
    )
)

:: Detect sysupgrade image (Standard or SmallBuffers)
set "SYSUPGRADE="
if exist "*sysupgrade.bin" (
    for %%f in (*sysupgrade.bin) do (
        if not defined SYSUPGRADE set "SYSUPGRADE=%%f"
    )
)

if not defined FACTORY (
    echo [ERROR] Factory UBI image (*factory.ubi) not found in current folder!
    echo         Please download it from GitHub Releases and place it here.
    pause
    exit /b 1
)

if not defined SYSUPGRADE (
    echo [ERROR] Sysupgrade binary (*sysupgrade.bin) not found in current folder!
    echo         Please download it from GitHub Releases and place it here.
    pause
    exit /b 1
)

if not exist "flash.sh" (
    echo [ERROR] flash.sh missing! Please ensure flash.sh is in the same folder.
    pause
    exit /b 1
)

echo [+] Detected Factory Image   : !FACTORY!
echo [+] Detected Sysupgrade Image: !SYSUPGRADE!
echo.

:: Wait for stock router
echo [*] Waiting for stock router at 192.168.31.1...
:WAIT_STOCK
ping -n 1 192.168.31.1 >nul 2>&1
if errorlevel 1 ( timeout /t 2 >nul & goto WAIT_STOCK )
echo [+] Connected to stock router!
echo.

:: Upload files
echo [*] Uploading !FACTORY! and flash.sh to router...
scp -O -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL "!FACTORY!" flash.sh root@192.168.31.1:/tmp/
if errorlevel 1 ( echo [ERROR] Upload failed! Make sure SSH is enabled on stock router. & pause & exit /b )
echo [+] Upload complete!
echo.

:: Execute flash.sh cleanly (stripping any Windows CRLF on router)
echo [*] Running flasher script on router...
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL root@192.168.31.1 "sed -i 's/\r$//' /tmp/flash.sh 2>/dev/null; sh /tmp/flash.sh"

echo.
echo [*] Factory image flashed. Waiting 90 seconds for router to reboot...
timeout /t 90 /nobreak
echo.

:: Wait for OpenWrt to come online at 192.168.1.1
echo [*] Probing for OpenWrt at 192.168.1.1...
:WAIT_OPENWRT
ping -n 1 192.168.1.1 >nul 2>&1
if errorlevel 1 ( timeout /t 2 >nul & goto WAIT_OPENWRT )
echo [+] OpenWrt is online!
echo.

:: Upload and apply sysupgrade
echo [*] Uploading permanent !SYSUPGRADE!...
timeout /t 5 >nul
scp -O -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL "!SYSUPGRADE!" root@192.168.1.1:/tmp/sysupgrade.bin
if errorlevel 1 ( echo [ERROR] Failed to upload sysupgrade.bin! & pause & exit /b )

echo [*] Applying permanent sysupgrade...
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL root@192.168.1.1 "sysupgrade -v -n /tmp/sysupgrade.bin"

echo.
echo [*] Sysupgrade triggered. Waiting 90 seconds for flash write and initial reboot...
timeout /t 90 /nobreak
echo.

echo =======================================================
echo   CONGRATULATIONS! OpenWrt Installed Successfully!
echo =======================================================
echo.
echo The router is booting into permanent OpenWrt.
echo Access LuCI WebUI at: http://192.168.1.1
echo.
pause
