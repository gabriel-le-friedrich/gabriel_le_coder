@echo off
set "PATH=C:\flutter\bin;%PATH%"
cd /d "%~dp0flutter_app"
set "LOG=%~dp0flutter_build_release_log.txt"

echo ===== flutter pub get ===== > "%LOG%"
call flutter pub get >> "%LOG%" 2>&1
echo PUBGET_EXIT=%ERRORLEVEL% >> "%LOG%"

echo ===== flutter build apk --release --split-per-abi ===== >> "%LOG%"
call flutter build apk --release --split-per-abi >> "%LOG%" 2>&1
echo BUILD_EXIT=%ERRORLEVEL% >> "%LOG%"

echo DONE >> "%LOG%"
