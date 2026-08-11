@echo off
REM ══════════════════════════════════════════════════════════════════════
REM Standard release build script for ASF Swine Finisher — universal APK
REM ONLY. Per standing instruction: never use --split-per-abi unless
REM explicitly requested for that one build; AAB is only for an explicit
REM Play Store release request (use flutter build appbundle --release then).
REM ══════════════════════════════════════════════════════════════════════
set "PATH=C:\flutter\bin;%PATH%"
cd /d "%~dp0flutter_app"
set "LOG=%~dp0flutter_release_universal_log.txt"
set "RELEASE_DIR=%~dp0release_apks"

if not exist "%RELEASE_DIR%" mkdir "%RELEASE_DIR%"

echo ===== START %DATE% %TIME% ===== > "%LOG%"

echo ----- flutter clean ----- >> "%LOG%"
call flutter clean >> "%LOG%" 2>&1

echo ----- flutter pub get ----- >> "%LOG%"
call flutter pub get >> "%LOG%" 2>&1

echo ----- flutter analyze ----- >> "%LOG%"
call flutter analyze >> "%LOG%" 2>&1

echo ----- flutter test ----- >> "%LOG%"
call flutter test >> "%LOG%" 2>&1

echo ----- flutter build apk --release (universal only) ----- >> "%LOG%"
call flutter build apk --release >> "%LOG%" 2>&1

echo ----- copy to release_apks ----- >> "%LOG%"
copy /Y "build\app\outputs\flutter-apk\app-release.apk" "%RELEASE_DIR%\app-release.apk" >> "%LOG%" 2>&1

echo ===== DONE %DATE% %TIME% ===== >> "%LOG%"
