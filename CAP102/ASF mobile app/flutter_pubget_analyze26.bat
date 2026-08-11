@echo off
set "PATH=C:\flutter\bin;%PATH%"
cd /d "%~dp0flutter_app"
echo ===== flutter analyze ===== > "%~dp0flutter_log26.txt"
call flutter analyze >> "%~dp0flutter_log26.txt" 2>&1
echo ANALYZE_EXIT=%ERRORLEVEL% >> "%~dp0flutter_log26.txt"
echo DONE >> "%~dp0flutter_log26.txt"
