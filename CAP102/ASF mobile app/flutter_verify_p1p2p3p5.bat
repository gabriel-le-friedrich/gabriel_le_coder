@echo off
set "PATH=C:\flutter\bin;%PATH%"
cd /d "%~dp0flutter_app"
set "LOG=%~dp0flutter_verify_p1p2p3p5_log.txt"
echo ===== dart format ===== > "%LOG%"
call dart format --output=none --set-exit-if-changed lib >> "%LOG%" 2>&1
echo FORMAT_EXIT=%ERRORLEVEL% >> "%LOG%"
echo ===== flutter test ===== >> "%LOG%"
call flutter test >> "%LOG%" 2>&1
echo TEST_EXIT=%ERRORLEVEL% >> "%LOG%"
echo ===== flutter build apk --release ===== >> "%LOG%"
call flutter build apk --release >> "%LOG%" 2>&1
echo BUILD_EXIT=%ERRORLEVEL% >> "%LOG%"
echo DONE >> "%LOG%"
