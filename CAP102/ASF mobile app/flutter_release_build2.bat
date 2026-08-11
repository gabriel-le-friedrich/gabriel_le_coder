@echo off
set "PATH=C:\flutter\bin;%PATH%"
cd /d "%~dp0flutter_app"
set "LOG=%~dp0flutter_release_build2_log.txt"

echo ===== flutter build apk --release ===== > "%LOG%"
call flutter build apk --release >> "%LOG%" 2>&1
echo APK_BUILD_EXIT=%ERRORLEVEL% >> "%LOG%"

echo ===== APK outputs ===== >> "%LOG%"
dir "build\app\outputs\flutter-apk" >> "%LOG%" 2>&1

echo DONE >> "%LOG%"
