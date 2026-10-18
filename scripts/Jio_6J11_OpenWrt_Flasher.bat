@echo off
setlocal
title Jio AX6000 6J11 OpenWrt Auto-Flasher
color

echo =======================================================
echo     Jio AX6000 6J11 - 1-Click OpenWrt Flasher
echo =======================================================
echo.

REM Detect files
set "FACTORY="
for %%f in (*factory.ubi) do set "FACTORY=%%f"

set "SYSUPGRADE="
for %%f in (*sysupgrade.bin) do set "SYSUPGRADE=%%f"

if "%FACTORY%"=="" ( echo [ERROR] No *factory.ubi found in current folder! & pause & exit /b 1 )
if "%SYSUPGRADE%"=="" ( echo [ERROR] No *sysupgrade.bin found in current folder! & pause & exit /b 1 )
if not exist "flash.sh" ( echo [ERROR] flash.sh missing! & pause & exit /b 1 )

echo [+] Factory Image   : %FACTORY%
echo [+] Sysupgrade Image: %SYSUPGRADE%
echo.

REM Wait for stock router
echo [*] Waiting for stock router at 192.168.31.1...
:WAIT_STOCK
ping -n 1 192.168.31.1 >nul 2>&1
if errorlevel 1 ( timeout /t 2 >nul & goto WAIT_STOCK )
echo [+] Connected to stock router!
echo.

REM Upload files
echo [*] Uploading %FACTORY% and flash.sh to router...
scp -O -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL "%FACTORY%" flash.sh root@192.168.31.1:/tmp/
if errorlevel 1 ( echo [ERROR] Upload failed! & pause & exit /b )
echo [+] Upload complete!
echo.

REM Run flash.sh on router
echo [*] Running flasher script on router...
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL root@192.168.31.1 "sed -i 's/\r$//' /tmp/flash.sh 2>/dev/null; sh /tmp/flash.sh"

echo.
echo [*] Factory image flashed. Waiting 90 seconds for router to reboot...
timeout /t 90 /nobreak
echo.

REM Wait for OpenWrt
echo [*] Probing for OpenWrt at 192.168.1.1...
:WAIT_OPENWRT
ping -n 1 192.168.1.1 >nul 2>&1
if errorlevel 1 ( timeout /t 2 >nul & goto WAIT_OPENWRT )
echo [+] OpenWrt is online!
echo.

REM Upload and apply sysupgrade
echo [*] Uploading permanent %SYSUPGRADE%...
timeout /t 5 >nul
scp -O -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL "%SYSUPGRADE%" root@192.168.1.1:/tmp/sysupgrade.bin
if errorlevel 1 ( echo [ERROR] Failed to upload sysupgrade! & pause & exit /b )

echo [*] Applying permanent sysupgrade...
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL root@192.168.1.1 "sysupgrade -v -n /tmp/sysupgrade.bin"

echo.
echo [*] Sysupgrade triggered. Waiting 90 seconds for final reboot...
timeout /t 90 /nobreak
echo.

echo =======================================================
echo   CONGRATULATIONS! OpenWrt Installed Successfully!
echo =======================================================
echo.
echo Access LuCI WebUI at: http://192.168.1.1
echo.
pause
