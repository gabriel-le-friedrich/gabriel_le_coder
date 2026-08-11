@echo off
set "PATH=C:\flutter\bin;%PATH%"
set LOG="C:\Users\erjan\OneDrive\Desktop\ASF mobile app\flutter_log4.txt"
cd /d "C:\Users\erjan\OneDrive\Desktop\ASF mobile app\flutter_app"
echo ===ANALYZE=== > %LOG%
call flutter analyze >> %LOG% 2>&1
echo ANALYZE_EXIT=%ERRORLEVEL% >> %LOG%
echo ===DONE=== >> %LOG%
