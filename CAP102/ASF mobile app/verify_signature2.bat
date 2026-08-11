@echo off
cd /d "%~dp0flutter_app"
echo ===== jarsigner -verify (Android Studio JBR) ===== > "%~dp0verify_signature_log2.txt"
"C:\Program Files\Android\Android Studio\jbr\bin\jarsigner.exe" -verify -verbose -certs "build\app\outputs\flutter-apk\app-release.apk" >> "%~dp0verify_signature_log2.txt" 2>&1
echo JARSIGNER_EXIT=%ERRORLEVEL% >> "%~dp0verify_signature_log2.txt"
echo DONE >> "%~dp0verify_signature_log2.txt"
