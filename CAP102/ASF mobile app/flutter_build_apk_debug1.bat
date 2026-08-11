@echo off
set "PATH=C:\flutter\bin;%PATH%"
cd /d "%~dp0flutter_app"
echo ===== flutter build apk --debug ===== > "%~dp0flutter_build_debug_log1.txt"
call flutter build apk --debug >> "%~dp0flutter_build_debug_log1.txt" 2>&1
echo BUILD_EXIT=%ERRORLEVEL% >> "%~dp0flutter_build_debug_log1.txt"
echo DONE >> "%~dp0flutter_build_debug_log1.txt"
