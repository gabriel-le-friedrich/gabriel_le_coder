@echo off
set "PATH=C:\flutter\bin;%PATH%"
cd /d "%~dp0flutter_app"
echo ===== flutter pub get ===== > "%~dp0flutter_log20.txt"
call flutter pub get >> "%~dp0flutter_log20.txt" 2>&1
echo PUB_GET_EXIT=%ERRORLEVEL% >> "%~dp0flutter_log20.txt"
echo ===== flutter analyze ===== >> "%~dp0flutter_log20.txt"
call flutter analyze >> "%~dp0flutter_log20.txt" 2>&1
echo ANALYZE_EXIT=%ERRORLEVEL% >> "%~dp0flutter_log20.txt"
echo DONE >> "%~dp0flutter_log20.txt"
