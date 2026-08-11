@echo off
set "PATH=C:\flutter\bin;%PATH%"
cd /d "%~dp0flutter_app"
echo ===== flutter analyze ===== > "%~dp0flutter_logging_verify_log.txt"
call flutter analyze >> "%~dp0flutter_logging_verify_log.txt" 2>&1
echo ANALYZE_EXIT=%ERRORLEVEL% >> "%~dp0flutter_logging_verify_log.txt"
echo ===== flutter test ===== >> "%~dp0flutter_logging_verify_log.txt"
call flutter test >> "%~dp0flutter_logging_verify_log.txt" 2>&1
echo TEST_EXIT=%ERRORLEVEL% >> "%~dp0flutter_logging_verify_log.txt"
echo DONE >> "%~dp0flutter_logging_verify_log.txt"
