@echo off
setlocal
cd /d "%~dp0"
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

REM ========== Find Python (no external files: .venv, then D:\envv, then system) ==========
set "PYTHON="
if exist ".venv\Scripts\python.exe" set "PYTHON=.venv\Scripts\python.exe"
if not defined PYTHON if exist "D:\envv\Scripts\python.exe" set "PYTHON=D:\envv\Scripts\python.exe"
if not defined PYTHON set "PYTHON=py -3"
if not defined PYTHON set "PYTHON=python"

%PYTHON% -c "pass" >nul 2>&1
if errorlevel 1 (
    echo [FAIL] Python not found. Install Python 3 and add to PATH.
    pause
    exit /b 1
)

REM ========== Docker must be running ==========
docker info >nul 2>&1
if errorlevel 1 (
    echo [FAIL] Docker not running. Start Docker Desktop and try again.
    pause
    exit /b 1
)

REM ========== Redis: use volume so cache survives stop/restart; ensure port 6379 ==========
REM If container missing or no port -> remove then create with volume redis-rag-data
powershell -NoProfile -Command "docker port redis-rag 6379 2>$null | Out-Null; if (-not $?) { docker rm -f redis-rag 2>$null; docker run -d --name redis-rag -p 6379:6379 -v redis-rag-data:/data redis:7-alpine } else { docker start redis-rag 2>$null | Out-Null; if (-not $?) { docker run -d --name redis-rag -p 6379:6379 -v redis-rag-data:/data redis:7-alpine } }" >nul 2>&1
timeout /t 2 /nobreak >nul

REM ========== Ports (optional: set API_PORT / STREAMLIT_PORT if 8000/8501 are in use) ==========
if not defined API_PORT set "API_PORT=8000"
if not defined STREAMLIT_PORT set "STREAMLIT_PORT=8501"

REM ========== Free ports if in use (avoids WinError 10013 from old RAG API/Streamlit) ==========
echo Freeing ports %API_PORT% and %STREAMLIT_PORT% if in use...
powershell -NoProfile -Command "$p=@(%API_PORT%,%STREAMLIT_PORT%); foreach($port in $p) { Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue } }"
timeout /t 2 /nobreak >nul

REM ========== Start API in new window ==========
start "RAG API" cmd /k "cd /d "%ROOT%" && %PYTHON% -m uvicorn app.main:app --reload --host 127.0.0.1 --port %API_PORT%"

REM ========== Wait then start Streamlit in new window ==========
timeout /t 6 /nobreak >nul
start "RAG Streamlit" cmd /k "cd /d "%ROOT%" && %PYTHON% -m streamlit run ui/streamlit_app.py --server.port %STREAMLIT_PORT%"

echo.
echo Ready.
echo   API:       http://127.0.0.1:%API_PORT%
echo   Streamlit: http://localhost:%STREAMLIT_PORT%
echo.
echo If WinError 10013 still appears: run this CMD as Administrator, or set API_PORT=8001 STREAMLIT_PORT=8502
pause
