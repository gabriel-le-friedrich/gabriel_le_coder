@echo off
set "PATH=C:\flutter\bin;%PATH%"
cd /d "%~dp0flutter_app"
echo ===== flutter build apk --release (signed, v1.1.0+2) ===== > "%~dp0flutter_build_log4.txt"
call flutter build apk --release >> "%~dp0flutter_build_log4.txt" 2>&1
echo BUILD_EXIT=%ERRORLEVEL% >> "%~dp0flutter_build_log4.txt"
echo ===== flutter build appbundle --release ===== >> "%~dp0flutter_build_log4.txt"
call flutter build appbundle --release >> "%~dp0flutter_build_log4.txt" 2>&1
echo AAB_BUILD_EXIT=%ERRORLEVEL% >> "%~dp0flutter_build_log4.txt"
echo DONE >> "%~dp0flutter_build_log4.txt"
