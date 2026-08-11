@echo off
setlocal
set "PATH=C:\Program Files\nodejs;%PATH%"
cd /d "%~dp0"
set "LOG=%~dp0supabase_deploy_lookupaccount_log.txt"

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

set SUPABASE_ACCESS_TOKEN=sbp_c1d1419ff2d9c7bdedafa9b3206dc303fd7f2276

echo ----- supabase link ----- >> "%LOG%"
call "%SUPABASE_CMD%" link --project-ref genxzsocmhgnxwwxjifz >> "%LOG%" 2>&1

echo ----- supabase functions deploy lookup-account ----- >> "%LOG%"
call "%SUPABASE_CMD%" functions deploy lookup-account --project-ref genxzsocmhgnxwwxjifz >> "%LOG%" 2>&1

echo ===== DONE %DATE% %TIME% ===== >> "%LOG%"
