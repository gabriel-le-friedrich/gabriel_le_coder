@echo off
set "PATH=C:\flutter\bin;%PATH%"
cd /d "%~dp0flutter_app"
set "LOG=%~dp0flutter_gen_icons_log.txt"

echo ===== START %DATE% %TIME% ===== > "%LOG%"

echo ----- flutter pub get ----- >> "%LOG%"
call flutter pub get >> "%LOG%" 2>&1

echo ----- dart run flutter_launcher_icons ----- >> "%LOG%"
call dart run flutter_launcher_icons >> "%LOG%" 2>&1

echo ===== DONE %DATE% %TIME% ===== >> "%LOG%"
