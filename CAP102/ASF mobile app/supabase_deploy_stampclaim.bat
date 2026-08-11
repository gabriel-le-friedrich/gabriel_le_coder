@echo off
setlocal
set "PATH=C:\Program Files\nodejs;%PATH%"
cd /d "%~dp0"
set "LOG=%~dp0supabase_deploy_stampclaim_log.txt"

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

set SUPABASE_ACCESS_TOKEN=sbp_d6b6945028b15a507458cce12b9be1fdc71669ce

echo ----- supabase link ----- >> "%LOG%"
call "%SUPABASE_CMD%" link --project-ref genxzsocmhgnxwwxjifz >> "%LOG%" 2>&1

echo ----- supabase secrets set (from env file) ----- >> "%LOG%"
call "%SUPABASE_CMD%" secrets set --env-file "%~dp0supabase\functions\.stamp_claim_secrets.env" --project-ref genxzsocmhgnxwwxjifz >> "%LOG%" 2>&1

echo ----- supabase functions deploy stamp-claim ----- >> "%LOG%"
call "%SUPABASE_CMD%" functions deploy stamp-claim --project-ref genxzsocmhgnxwwxjifz >> "%LOG%" 2>&1

echo ===== DONE %DATE% %TIME% ===== >> "%LOG%"
