@echo off
set "PATH=C:\flutter\bin;%PATH%"
cd /d "%~dp0flutter_app"
set "LOG=%~dp0flutter_weightredesign2_verify_log.txt"
echo ===== dart format (apply) ===== > "%LOG%"
call dart format lib >> "%LOG%" 2>&1
echo FORMAT_EXIT=%ERRORLEVEL% >> "%LOG%"
echo ===== flutter analyze ===== >> "%LOG%"
call flutter analyze >> "%LOG%" 2>&1
echo ANALYZE_EXIT=%ERRORLEVEL% >> "%LOG%"
echo ===== flutter test ===== >> "%LOG%"
call flutter test >> "%LOG%" 2>&1
echo TEST_EXIT=%ERRORLEVEL% >> "%LOG%"
echo ===== flutter build apk --release ===== >> "%LOG%"
call flutter build apk --release >> "%LOG%" 2>&1
echo BUILD_EXIT=%ERRORLEVEL% >> "%LOG%"
echo DONE >> "%LOG%"
