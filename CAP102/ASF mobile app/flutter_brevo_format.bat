@echo off
REM Brevo integration — dart format pass, run once before the canonical
REM flutter_release_universal.bat build/analyze/test pass.
set "PATH=C:\flutter\bin;%PATH%"
cd /d "%~dp0flutter_app"
set "LOG=%~dp0flutter_brevo_format_log.txt"

echo ===== START %DATE% %TIME% ===== > "%LOG%"
echo ----- dart format . ----- >> "%LOG%"
call dart format . >> "%LOG%" 2>&1
echo ===== DONE %DATE% %TIME% ===== >> "%LOG%"
