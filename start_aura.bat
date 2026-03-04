@echo off
setlocal EnableDelayedExpansion
title AURA Launcher
echo +--------------------------------------+
echo I        AURA System Launcher          I
echo I     Zero-Docker Architecture         I
echo +--------------------------------------+
echo.

:: ─── Cleanup Existing Services ──────────────
echo Cleaning up existing AURA services...
taskkill /F /FI "WINDOWTITLE eq AURA Token Server" /T >nul 2>&1
taskkill /F /FI "WINDOWTITLE eq AURA Voice Agent" /T >nul 2>&1
taskkill /F /FI "WINDOWTITLE eq AURA AI Service" /T >nul 2>&1
taskkill /F /FI "WINDOWTITLE eq AURA Dashboard" /T >nul 2>&1
timeout /t 1 /nobreak >nul

:: ─── Python Check ──────────────────
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python is not installed or not in PATH.
    pause
    exit /b 1
)

for /f "tokens=2 delims= " %%v in ('python --version') do set PY_VER=%%v
echo Detected Python %PY_VER%

:: ─── 0. Setup Virtual Environments ──────────
echo [0/4] Checking environments...

:: AI Service
if not exist "ai-service\venv" (
    echo Creating AI Service venv...
    python -m venv ai-service\venv
)

echo Installing/Updating AI Service dependencies...
call ai-service\venv\Scripts\activate
pip install --prefer-binary -r ai-service\requirements.txt
call deactivate

:: Voice Agent dependencies installed into conda 'aura'
echo Installing/Updating Voice Agent dependencies in conda 'aura'...

call conda env list | findstr /R "\<aura\>" >nul
if %errorlevel% neq 0 (
    echo [ERROR] Conda environment 'aura' not found!
    echo Please create it before running the launcher.
    pause
    exit /b 1
)

call conda activate aura
cd voice-agent

echo Installing/Verifying Voice Agent dependencies...
pip install --prefer-binary -r requirements.txt

cd ..
call conda deactivate

echo.
echo Environments ready. Starting services...
echo.

:: ─── 1. Token Server ────────────────────────
echo [1/4] Starting Token Server (port 8082)...
start "AURA Token Server" cmd /k "cd voice-agent & call conda activate aura & python token_server.py"
timeout /t 2 /nobreak >nul

:: ─── 2. Voice Agent ─────────────────────────
echo [2/4] Starting Voice Agent...

set "TTS_TYPE=qwen"
for /f "tokens=2 delims==" %%a in ('findstr /I "^TTS_TYPE=" ".env"') do set "TTS_TYPE=%%a"

if /I "!TTS_TYPE!"=="qwen" (
    echo Detect TTS_TYPE=qwen. Verifying 'aura' conda environment...
    call conda env list | findstr /R "\<aura\>" >nul
    if !errorlevel! neq 0 (
        echo [ERROR] Conda environment 'aura' not found!
        pause
        exit /b 1
    )
    start "AURA Voice Agent" cmd /k "cd voice-agent & call conda activate aura & python agent.py dev"
) else (
    echo Detect TTS_TYPE=!TTS_TYPE! ^(Cloud^). Using standard venv...
    start "AURA Voice Agent" cmd /k "cd voice-agent & python agent.py dev"
)
timeout /t 2 /nobreak >nul

:: ─── 3. AI Service ──────────────────────────
echo [3/4] Starting AI Service (port 8000)...
start "AURA AI Service" cmd /k "cd ai-service & venv\Scripts\activate & python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload"
timeout /t 2 /nobreak >nul

:: ─── Dashboard Dependency Check ─────────────
echo Checking Dashboard dependencies...

if not exist "dashboard\node_modules" (
    echo Installing Dashboard dependencies...
    cd dashboard
    npm install
    cd ..
) else (
    echo Dashboard dependencies already installed.
)

:: ─── 4. Dashboard ───────────────────────────
echo [4/4] Starting Dashboard (port 5173)...
start "AURA Dashboard" cmd /k "cd dashboard & npm run dev -- --host"
timeout /t 5 /nobreak >nul

echo.
echo All services running! Close this window or CTRL+C to stop.
pause