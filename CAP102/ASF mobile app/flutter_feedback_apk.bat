@echo off
set "PATH=C:\flutter\bin;%PATH%"
cd /d "%~dp0flutter_app"
set "LOG=%~dp0flutter_feedback_apk_log.txt"

echo ===== flutter build apk --debug --split-per-abi ===== > "%LOG%"
call flutter build apk --debug --split-per-abi >> "%LOG%" 2>&1
echo BUILD_EXIT=%ERRORLEVEL% >> "%LOG%"

echo ===== list outputs ===== >> "%LOG%"
dir "build\app\outputs\flutter-apk" >> "%LOG%" 2>&1

echo DONE >> "%LOG%"
