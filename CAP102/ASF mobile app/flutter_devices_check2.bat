@echo off
set "PATH=C:\flutter\bin;%PATH%"
cd /d "%~dp0flutter_app"
echo ===== flutter devices ===== > "%~dp0flutter_devices_check2_log.txt"
call flutter devices >> "%~dp0flutter_devices_check2_log.txt" 2>&1
echo DONE >> "%~dp0flutter_devices_check2_log.txt"
