@echo off
REM ══════════════════════════════════════════════════════════════════════
REM Verify build for the Settings UI Redesign (main Settings, Profile &
REM Farm, Notification Settings restyle, Synchronization, Data Management,
REM Offline Mode, Privacy & Security, Help & Support). Universal release
REM APK only, per standing policy.
REM ══════════════════════════════════════════════════════════════════════
set "PATH=C:\flutter\bin;%PATH%"
cd /d "%~dp0flutter_app"
set "LOG=%~dp0flutter_settingsredesign_verify_log.txt"
set "RELEASE_DIR=%~dp0release_apks"

if not exist "%RELEASE_DIR%" mkdir "%RELEASE_DIR%"

echo ===== START %DATE% %TIME% ===== > "%LOG%"

echo ----- dart format ----- >> "%LOG%"
call dart format lib >> "%LOG%" 2>&1

echo ----- flutter pub get ----- >> "%LOG%"
call flutter pub get >> "%LOG%" 2>&1

echo ----- flutter analyze ----- >> "%LOG%"
call flutter analyze >> "%LOG%" 2>&1
echo ANALYZE_EXIT=%ERRORLEVEL% >> "%LOG%"

echo ----- flutter test ----- >> "%LOG%"
call flutter test >> "%LOG%" 2>&1
echo TEST_EXIT=%ERRORLEVEL% >> "%LOG%"

echo ----- flutter build apk --release (universal only) ----- >> "%LOG%"
call flutter build apk --release >> "%LOG%" 2>&1
echo BUILD_EXIT=%ERRORLEVEL% >> "%LOG%"

echo ----- copy to release_apks ----- >> "%LOG%"
copy /Y "build\app\outputs\flutter-apk\app-release.apk" "%RELEASE_DIR%\app-release.apk" >> "%LOG%" 2>&1

echo ===== DONE %DATE% %TIME% ===== >> "%LOG%"
