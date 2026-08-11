@echo off
set "PATH=C:\flutter\bin;%PATH%"
cd /d "C:\Users\erjan\OneDrive\Desktop\ASF mobile app\flutter_app"
set LOG="C:\Users\erjan\OneDrive\Desktop\ASF mobile app\flutter_bugfix_verify.log"
echo ===== START %DATE% %TIME% ===== > %LOG%

echo ----- flutter clean ----- >> %LOG%
call flutter clean >> %LOG% 2>&1

echo ----- flutter pub get ----- >> %LOG%
call flutter pub get >> %LOG% 2>&1

echo ----- flutter analyze ----- >> %LOG%
call flutter analyze >> %LOG% 2>&1

echo ----- flutter test ----- >> %LOG%
call flutter test >> %LOG% 2>&1

echo ----- flutter build apk --release --split-per-abi ----- >> %LOG%
call flutter build apk --release --split-per-abi >> %LOG% 2>&1

echo ----- flutter build apk --release (universal) ----- >> %LOG%
call flutter build apk --release >> %LOG% 2>&1

echo ===== DONE %DATE% %TIME% ===== >> %LOG%
