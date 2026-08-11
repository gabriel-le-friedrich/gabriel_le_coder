@echo off
set "PATH=C:\flutter\bin;%PATH%"
cd /d "%~dp0flutter_app"
set "LOG=%~dp0flutter_finalqa_verify_log.txt"

echo ===== flutter analyze ===== > "%LOG%"
call flutter analyze >> "%LOG%" 2>&1
echo ANALYZE_EXIT=%ERRORLEVEL% >> "%LOG%"

echo ===== flutter test ===== >> "%LOG%"
call flutter test >> "%LOG%" 2>&1
echo TEST_EXIT=%ERRORLEVEL% >> "%LOG%"

echo ===== flutter build apk --release ===== >> "%LOG%"
call flutter build apk --release >> "%LOG%" 2>&1
echo APK_EXIT=%ERRORLEVEL% >> "%LOG%"

echo ===== flutter build appbundle --release ===== >> "%LOG%"
call flutter build appbundle --release >> "%LOG%" 2>&1
echo AAB_EXIT=%ERRORLEVEL% >> "%LOG%"

echo DONE >> "%LOG%"
