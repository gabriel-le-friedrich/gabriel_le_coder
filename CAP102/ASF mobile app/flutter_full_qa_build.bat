@echo off
set "PATH=C:\flutter\bin;%PATH%"
cd /d "%~dp0flutter_app"
set "LOG=%~dp0flutter_full_qa_log.txt"

echo ===== flutter clean ===== > "%LOG%"
call flutter clean >> "%LOG%" 2>&1
echo CLEAN_EXIT=%ERRORLEVEL% >> "%LOG%"

echo ===== flutter pub get ===== >> "%LOG%"
call flutter pub get >> "%LOG%" 2>&1
echo PUBGET_EXIT=%ERRORLEVEL% >> "%LOG%"

echo ===== flutter analyze ===== >> "%LOG%"
call flutter analyze >> "%LOG%" 2>&1
echo ANALYZE_EXIT=%ERRORLEVEL% >> "%LOG%"

echo ===== flutter test ===== >> "%LOG%"
call flutter test >> "%LOG%" 2>&1
echo TEST_EXIT=%ERRORLEVEL% >> "%LOG%"

echo ===== flutter build apk --debug ===== >> "%LOG%"
call flutter build apk --debug >> "%LOG%" 2>&1
echo BUILD_EXIT=%ERRORLEVEL% >> "%LOG%"

echo DONE >> "%LOG%"
