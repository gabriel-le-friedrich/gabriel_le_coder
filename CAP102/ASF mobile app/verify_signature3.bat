@echo off
cd /d "%~dp0flutter_app"
echo ===== build-tools dirs ===== > "%~dp0verify_signature_log3.txt"
dir /b "%LOCALAPPDATA%\Android\Sdk\build-tools" >> "%~dp0verify_signature_log3.txt" 2>&1
echo ===== apksigner verify ===== >> "%~dp0verify_signature_log3.txt"
for /f "delims=" %%v in ('dir /b /o-n "%LOCALAPPDATA%\Android\Sdk\build-tools"') do (
  if not defined LATEST set "LATEST=%%v"
)
echo Using build-tools: %LATEST% >> "%~dp0verify_signature_log3.txt"
call "%LOCALAPPDATA%\Android\Sdk\build-tools\%LATEST%\apksigner.bat" verify --verbose --print-certs "build\app\outputs\flutter-apk\app-release.apk" >> "%~dp0verify_signature_log3.txt" 2>&1
echo APKSIGNER_EXIT=%ERRORLEVEL% >> "%~dp0verify_signature_log3.txt"
echo DONE >> "%~dp0verify_signature_log3.txt"
