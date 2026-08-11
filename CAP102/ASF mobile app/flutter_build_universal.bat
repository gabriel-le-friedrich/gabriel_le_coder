@echo off
set "PATH=C:\flutter\bin;%PATH%"
cd /d "C:\Users\erjan\OneDrive\Desktop\ASF mobile app\flutter_app"
set LOG="C:\Users\erjan\OneDrive\Desktop\ASF mobile app\flutter_build_universal.log"
echo ===== START %DATE% %TIME% ===== > %LOG%

echo ----- flutter build apk --release (universal) ----- >> %LOG%
call flutter build apk --release >> %LOG% 2>&1

echo ===== DONE %DATE% %TIME% ===== >> %LOG%
