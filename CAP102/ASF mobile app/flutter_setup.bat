@echo off
set "PATH=C:\flutter\bin;%PATH%"
cd /d "C:\Users\erjan\OneDrive\Desktop\ASF mobile app"
echo ===STEP0 START=== > flutter_setup_log.txt
echo %DATE% %TIME% >> flutter_setup_log.txt
where flutter >> flutter_setup_log.txt 2>&1
echo ===STEP1 flutter create=== >> flutter_setup_log.txt
call flutter create --org com.asf --project-name asf_flutter --platforms android flutter_app_scaffold >> flutter_setup_log.txt 2>&1
echo STEP1_EXIT=%ERRORLEVEL% >> flutter_setup_log.txt
echo ===STEP2 copy android folder=== >> flutter_setup_log.txt
xcopy /E /I /Y "flutter_app_scaffold\android" "flutter_app\android" >> flutter_setup_log.txt 2>&1
echo STEP2_EXIT=%ERRORLEVEL% >> flutter_setup_log.txt
echo ===STEP3 copy .metadata=== >> flutter_setup_log.txt
xcopy /E /I /Y "flutter_app_scaffold\.metadata" "flutter_app\.metadata" >> flutter_setup_log.txt 2>&1
echo STEP3_EXIT=%ERRORLEVEL% >> flutter_setup_log.txt
echo ===STEP4 copy google-services.json=== >> flutter_setup_log.txt
copy /Y "android\app\google-services.json" "flutter_app\android\app\google-services.json" >> flutter_setup_log.txt 2>&1
echo STEP4_EXIT=%ERRORLEVEL% >> flutter_setup_log.txt
echo ===STEP5 cleanup scaffold=== >> flutter_setup_log.txt
rmdir /S /Q "flutter_app_scaffold" >> flutter_setup_log.txt 2>&1
echo STEP5_EXIT=%ERRORLEVEL% >> flutter_setup_log.txt
echo ===STEP6 pub get=== >> flutter_setup_log.txt
cd /d "C:\Users\erjan\OneDrive\Desktop\ASF mobile app\flutter_app"
call flutter pub get >> "C:\Users\erjan\OneDrive\Desktop\ASF mobile app\flutter_setup_log.txt" 2>&1
echo STEP6_EXIT=%ERRORLEVEL% >> "C:\Users\erjan\OneDrive\Desktop\ASF mobile app\flutter_setup_log.txt"
echo ===STEP7 analyze=== >> "C:\Users\erjan\OneDrive\Desktop\ASF mobile app\flutter_setup_log.txt"
call flutter analyze >> "C:\Users\erjan\OneDrive\Desktop\ASF mobile app\flutter_setup_log.txt" 2>&1
echo STEP7_EXIT=%ERRORLEVEL% >> "C:\Users\erjan\OneDrive\Desktop\ASF mobile app\flutter_setup_log.txt"
echo ===ALL_STEPS_DONE=== >> "C:\Users\erjan\OneDrive\Desktop\ASF mobile app\flutter_setup_log.txt"
