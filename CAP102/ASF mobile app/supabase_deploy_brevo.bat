@echo off
setlocal
set "PATH=C:\Program Files\nodejs;%PATH%"
cd /d "%~dp0"
set "LOG=%~dp0supabase_deploy_brevo_log.txt"

echo ===== START %DATE% %TIME% ===== > "%LOG%"

echo ----- checking for supabase CLI ----- >> "%LOG%"
where supabase >> "%LOG%" 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo supabase CLI not found on PATH, installing locally via npm... >> "%LOG%"
    call npm install supabase --no-save >> "%LOG%" 2>&1
    set "SUPABASE_CMD=%~dp0node_modules\.bin\supabase.cmd"
) else (
    set "SUPABASE_CMD=supabase"
)

echo Using SUPABASE_CMD=%SUPABASE_CMD% >> "%LOG%"

set SUPABASE_ACCESS_TOKEN=sbp_1b893bf1dec5869d83404302625e46fd7e8e1c1d

echo ----- supabase link ----- >> "%LOG%"
call "%SUPABASE_CMD%" link --project-ref genxzsocmhgnxwwxjifz >> "%LOG%" 2>&1

echo ----- supabase secrets set ----- >> "%LOG%"
call "%SUPABASE_CMD%" secrets set BREVO_API_KEY="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" SENDER_EMAIL="asfmanagement31@gmail.com" SENDER_NAME="Administration for Swine Finisher" ADMIN_EMAIL="asfmanagement31@gmail.com" --project-ref genxzsocmhgnxwwxjifz >> "%LOG%" 2>&1

echo ----- supabase functions deploy send-email ----- >> "%LOG%"
call "%SUPABASE_CMD%" functions deploy send-email --project-ref genxzsocmhgnxwwxjifz >> "%LOG%" 2>&1

echo ===== DONE %DATE% %TIME% ===== >> "%LOG%"
