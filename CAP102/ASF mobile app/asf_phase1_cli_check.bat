@echo off
set "LOG=%~dp0asf_phase1_cli_check_log.txt"
echo ==== whoami / date ==== > "%LOG%"
whoami >> "%LOG%" 2>&1
date /t >> "%LOG%" 2>&1

echo ==== firebase --version ==== >> "%LOG%"
where firebase >> "%LOG%" 2>&1
call firebase --version >> "%LOG%" 2>&1

echo ==== firebase login:list ==== >> "%LOG%"
call firebase login:list >> "%LOG%" 2>&1

echo ==== firebase projects:list ==== >> "%LOG%"
call firebase projects:list >> "%LOG%" 2>&1

echo ==== firebase use (current project in this dir) ==== >> "%LOG%"
cd /d "%~dp0"
call firebase use >> "%LOG%" 2>&1

echo ==== node --version / npm --version ==== >> "%LOG%"
call node --version >> "%LOG%" 2>&1
call npm --version >> "%LOG%" 2>&1

echo ==== keytool SHA fingerprints of release keystore ==== >> "%LOG%"
echo (reads flutter_app\android\keystore.properties for the store password) >> "%LOG%"
for /f "tokens=1,2 delims== " %%a in (flutter_app\android\keystore.properties) do (
  if "%%a"=="storePassword" set STOREPW=%%b
  if "%%a"=="keyAlias" set KEYALIAS=%%b
)
keytool -list -v -keystore flutter_app\android\app\asf-release.jks -storepass "%STOREPW%" -alias "%KEYALIAS%" 2>&1 | findstr /C:"SHA1" /C:"SHA256" /C:"Alias name" >> "%LOG%" 2>&1

echo DONE >> "%LOG%"
