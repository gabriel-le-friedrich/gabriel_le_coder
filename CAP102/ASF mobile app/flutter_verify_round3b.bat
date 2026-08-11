@echo off
set "PATH=C:\flutter\bin;%PATH%"
cd /d "C:\Users\erjan\OneDrive\Desktop\ASF mobile app\flutter_app"
set LOG="C:\Users\erjan\OneDrive\Desktop\ASF mobile app\flutter_verify_round3b.log"
echo ===== START %DATE% %TIME% ===== > %LOG%

echo ----- flutter analyze ----- >> %LOG%
call flutter analyze >> %LOG% 2>&1

echo ----- flutter test ----- >> %LOG%
call flutter test >> %LOG% 2>&1

echo ===== DONE %DATE% %TIME% ===== >> %LOG%
