@echo off
setlocal
cd /d "%~dp0"

rem ---------------------------------------------------------------------------
rem Brings up both back-ends and then the Flutter web client, in one go.
rem
rem   career_engine  ->  127.0.0.1:8001   (this repo, career_engine\)
rem   match_engine   ->  127.0.0.1:8000   (sibling repo, ..\match_engine\)
rem   Flutter web    ->  127.0.0.1:5050   (foreground; Ctrl+C to stop)
rem
rem Each back-end opens in its own window. When the Flutter process exits,
rem this script closes those windows again. run_web.bat still runs the client
rem on its own if you don't want the back-ends.
rem ---------------------------------------------------------------------------

set "ROOT=%~dp0"
for %%I in ("%ROOT%career_engine") do set "CAREER_DIR=%%~fI"
for %%I in ("%ROOT%..\match_engine") do set "MATCH_DIR=%%~fI"

set "CAREER_TITLE=career_engine :8001"
set "MATCH_TITLE=match_engine :8000"

call :ensure_venv "career_engine" "%CAREER_DIR%"
call :ensure_venv "match_engine"  "%MATCH_DIR%"

echo(
echo [run] starting %CAREER_TITLE%
start "%CAREER_TITLE%" /D "%CAREER_DIR%" cmd /k ".venv\Scripts\python.exe run_server.py"

if exist "%MATCH_DIR%\run_server.py" (
  echo [run] starting %MATCH_TITLE%
  start "%MATCH_TITLE%" /D "%MATCH_DIR%" cmd /k ".venv\Scripts\python.exe run_server.py"
) else (
  echo [run] WARNING: %MATCH_DIR%\run_server.py not found - skipping match_engine
)

echo [run] waiting for the back-ends to bind...
timeout /t 3 /nobreak >nul 2>&1 || ping -n 4 127.0.0.1 >nul

echo [run] starting Flutter web client on 127.0.0.1:5050
call flutter\bin\flutter.bat run -d web-server --web-port 5050 --web-hostname 127.0.0.1

echo(
echo [run] Flutter exited - stopping the back-ends
rem Primary: close the two windows we opened (kills cmd + python + reloader).
taskkill /FI "WINDOWTITLE eq %CAREER_TITLE%" /T /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq %MATCH_TITLE%"  /T /F >nul 2>&1
rem Fallback: sweep any run_server.py still alive (reload children, detached runs).
powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | Where-Object { $_.CommandLine -match 'run_server\.py' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }" >nul 2>&1

endlocal
exit /b 0

rem ---------------------------------------------------------------------------
:ensure_venv
rem  %~1 = label for messages, %~2 = engine directory
set "_LABEL=%~1"
set "_DIR=%~2"
if not exist "%_DIR%" (
  echo [setup] ERROR: %_LABEL% directory not found: %_DIR%
  exit /b 1
)
if exist "%_DIR%\.venv\Scripts\python.exe" (
  exit /b 0
)
echo [setup] creating .venv for %_LABEL% in %_DIR%
pushd "%_DIR%"
python -m venv .venv
".venv\Scripts\python.exe" -m pip install --disable-pip-version-check -q -r requirements.txt
popd
exit /b 0
