@echo off
set "PATH=C:\flutter\bin;%PATH%"
cd /d "%~dp0flutter_app"
echo ===== flutter pub get ===== > "%~dp0flutter_log28.txt"
call flutter pub get >> "%~dp0flutter_log28.txt" 2>&1
echo PUBGET_EXIT=%ERRORLEVEL% >> "%~dp0flutter_log28.txt"
echo ===== flutter analyze ===== >> "%~dp0flutter_log28.txt"
call flutter analyze >> "%~dp0flutter_log28.txt" 2>&1
echo ANALYZE_EXIT=%ERRORLEVEL% >> "%~dp0flutter_log28.txt"
echo DONE >> "%~dp0flutter_log28.txt"
