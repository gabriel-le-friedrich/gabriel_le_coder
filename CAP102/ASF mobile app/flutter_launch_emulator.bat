@echo off
set "PATH=C:\flutter\bin;%PATH%"
cd /d "%~dp0flutter_app"
echo ===== launching emulator ===== > "%~dp0flutter_emulator_launch_log.txt"
start "" cmd /c "flutter emulators --launch Medium_Phone_API_36.1 >> "%~dp0flutter_emulator_launch_log.txt" 2>&1"
echo LAUNCH_TRIGGERED >> "%~dp0flutter_emulator_launch_log.txt"
