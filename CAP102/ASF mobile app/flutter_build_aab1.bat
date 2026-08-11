@echo off
set "PATH=C:\flutter\bin;%PATH%"
cd /d "%~dp0flutter_app"
echo ===== flutter build appbundle --release ===== > "%~dp0flutter_build_log3.txt"
call flutter build appbundle --release >> "%~dp0flutter_build_log3.txt" 2>&1
echo BUILD_EXIT=%ERRORLEVEL% >> "%~dp0flutter_build_log3.txt"
echo DONE >> "%~dp0flutter_build_log3.txt"
