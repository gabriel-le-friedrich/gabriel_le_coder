@echo off
echo ============================================
echo ASF - Firebase Cloud Function Deploy
echo ============================================
cd /d "C:\Users\erjan\OneDrive\Desktop\ASF mobile app\functions"

echo.
echo [1/4] Installing function dependencies...
call npm install
if errorlevel 1 goto :error

echo.
echo [2/4] Ensuring firebase-tools is installed globally...
call npm install -g firebase-tools
if errorlevel 1 goto :error

echo.
echo [3/4] Logging in to Firebase (a browser window will open)...
call firebase login
if errorlevel 1 goto :error

echo.
echo [4/4] Deploying Cloud Function to project asf-app-2990c...
call firebase deploy --only functions --project asf-app-2990c
if errorlevel 1 goto :error

echo.
echo ============================================
echo SUCCESS - Cloud Function deployed.
echo ============================================
goto :end

:error
echo.
echo ============================================
echo ERROR - something failed above. Scroll up to see details.
echo ============================================

:end
echo.
pause
