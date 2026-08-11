@echo off
set "PATH=C:\flutter\bin;%PATH%"
cd /d "C:\Users\erjan\OneDrive\Desktop\ASF mobile app"
set LOG="C:\Users\erjan\OneDrive\Desktop\ASF mobile app\flutter_setup_log2.txt"
echo ===STEP3 copy .metadata (file, not xcopy)=== > %LOG%
copy /Y "flutter_app_scaffold\.metadata" "flutter_app\.metadata" >> %LOG% 2>&1
echo STEP3_EXIT=%ERRORLEVEL% >> %LOG%
echo ===STEP4 copy google-services.json=== >> %LOG%
copy /Y "android\app\google-services.json" "flutter_app\android\app\google-services.json" >> %LOG% 2>&1
echo STEP4_EXIT=%ERRORLEVEL% >> %LOG%
echo ===STEP5 cleanup scaffold=== >> %LOG%
rmdir /S /Q "flutter_app_scaffold" >> %LOG% 2>&1
echo STEP5_EXIT=%ERRORLEVEL% >> %LOG%
echo ===STEP6 pub get=== >> %LOG%
cd /d "C:\Users\erjan\OneDrive\Desktop\ASF mobile app\flutter_app"
call flutter pub get >> %LOG% 2>&1
echo STEP6_EXIT=%ERRORLEVEL% >> %LOG%
echo ===STEP7 analyze=== >> %LOG%
call flutter analyze >> %LOG% 2>&1
echo STEP7_EXIT=%ERRORLEVEL% >> %LOG%
echo ===ALL_STEPS_DONE=== >> %LOG%
