@echo off
set "PATH=C:\flutter\bin;%PATH%"
cd /d "%~dp0flutter_app"
echo ===== jarsigner -verify ===== > "%~dp0verify_signature_log.txt"
jarsigner -verify -verbose -certs "build\app\outputs\flutter-apk\app-release.apk" >> "%~dp0verify_signature_log.txt" 2>&1
echo JARSIGNER_EXIT=%ERRORLEVEL% >> "%~dp0verify_signature_log.txt"
echo DONE >> "%~dp0verify_signature_log.txt"
