@echo off
set "PATH=C:\flutter\bin;%PATH%"
cd /d "%~dp0flutter_app"
echo ===== dart format (apply) ===== > "%~dp0flutter_format_apply_log.txt"
call dart format lib >> "%~dp0flutter_format_apply_log.txt" 2>&1
echo FORMAT_EXIT=%ERRORLEVEL% >> "%~dp0flutter_format_apply_log.txt"
echo DONE >> "%~dp0flutter_format_apply_log.txt"
