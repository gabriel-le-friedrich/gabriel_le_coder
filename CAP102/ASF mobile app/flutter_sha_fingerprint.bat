@echo off
set "LOG=%~dp0flutter_sha_fingerprint_log.txt"
set "KEYSTORE=%~dp0flutter_app\android\app\asf-release.jks"

echo ==== locating keytool ==== > "%LOG%"
where keytool >> "%LOG%" 2>&1
if errorlevel 1 (
  echo keytool not on PATH, trying Android Studio bundled JBR >> "%LOG%"
  set "KEYTOOL=C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
) else (
  set "KEYTOOL=keytool"
)

echo Using KEYTOOL=%KEYTOOL% >> "%LOG%"
echo Using KEYSTORE=%KEYSTORE% >> "%LOG%"

echo ==== keytool -list -v ==== >> "%LOG%"
"%KEYTOOL%" -list -v -keystore "%KEYSTORE%" -alias asf-key -storepass "ASFSwine2024!" -keypass "ASFSwine2024!" >> "%LOG%" 2>&1
echo KEYTOOL_EXIT=%ERRORLEVEL% >> "%LOG%"
echo DONE >> "%LOG%"
