@echo off
set "PATH=C:\flutter\bin;%PATH%"
cd /d "%~dp0flutter_app"
set "LOG=%~dp0flutter_expenseredesign_apk_log.txt"

echo ===== flutter build apk --debug ===== > "%LOG%"
call flutter build apk --debug >> "%LOG%" 2>&1
echo BUILD_EXIT=%ERRORLEVEL% >> "%LOG%"

echo DONE >> "%LOG%"
