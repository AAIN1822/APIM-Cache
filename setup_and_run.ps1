# =============================================================================
# SETUP AND RUN - One double-click to set up and start the RAG app on Windows.
# Idempotent: safe to run again (reuses existing .venv, skips already-installed).
# =============================================================================

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
$VenvPath = Join-Path $ProjectRoot ".venv"
$VenvPython = Join-Path $VenvPath "Scripts\python.exe"
$VenvPip = Join-Path $VenvPath "Scripts\pip.exe"

# -----------------------------------------------------------------------------
# Step 0: Check required software (Python, pip, Docker)
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Checking required software ===" -ForegroundColor Cyan

# Prefer "py" (Windows launcher) then "python"
$pythonCmd = $null
try { & py -3 --version 2>$null | Out-Null; if ($?) { $pythonCmd = "py" } } catch {}
if (-not $pythonCmd) {
    try { & python --version 2>$null | Out-Null; if ($?) { $pythonCmd = "python" } } catch {}
}
if (-not $pythonCmd) {
    Write-Host ""
    Write-Host "  [FAIL] Python 3 is not installed or not in PATH." -ForegroundColor Red
    Write-Host "  Install from: https://www.python.org/downloads/" -ForegroundColor Yellow
    Write-Host "  Tick 'Add Python to PATH' during installation." -ForegroundColor Yellow
    Write-Host ""
    pause
    exit 1
}
Write-Host "  Python: OK" -ForegroundColor Green

# Check pip
$pipOk = $false
if ($pythonCmd -eq "py") { try { & py -3 -m pip --version 2>$null | Out-Null; $pipOk = $? } catch {} }
if (-not $pipOk -and $pythonCmd -eq "python") { try { & python -m pip --version 2>$null | Out-Null; $pipOk = $? } catch {} }
if (-not $pipOk) {
    Write-Host ""
    Write-Host "  [FAIL] pip is not available. Reinstall Python with pip option." -ForegroundColor Red
    Write-Host ""
    pause
    exit 1
}
Write-Host "  pip: OK" -ForegroundColor Green

$dockerOk = $false
try { docker info 2>$null | Out-Null; $dockerOk = $true } catch {}
if (-not $dockerOk) {
    Write-Host ""
    Write-Host "  [FAIL] Docker is not installed or Docker Desktop is not running." -ForegroundColor Red
    Write-Host "  Install Docker Desktop: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    Write-Host "  Start Docker Desktop and run this script again." -ForegroundColor Yellow
    Write-Host ""
    pause
    exit 1
}
Write-Host "  Docker: OK" -ForegroundColor Green
Write-Host ""

# -----------------------------------------------------------------------------
# Step 1: Create virtual environment (idempotent)
# -----------------------------------------------------------------------------
Write-Host "=== Virtual environment ===" -ForegroundColor Cyan
if (-not (Test-Path $VenvPython)) {
    Write-Host "  Creating .venv in project folder..." -ForegroundColor Yellow
    if ($pythonCmd -eq "py") {
        & py -3 -m venv $VenvPath
    } else {
        & python -m venv $VenvPath
    }
    if (-not (Test-Path $VenvPython)) {
        Write-Host "  [FAIL] Could not create .venv" -ForegroundColor Red
        pause
        exit 1
    }
    Write-Host "  Created: $VenvPath" -ForegroundColor Green
} else {
    Write-Host "  Using existing .venv" -ForegroundColor Green
}
Write-Host ""

# -----------------------------------------------------------------------------
# Step 2: Install dependencies (idempotent; pip skips already installed)
# -----------------------------------------------------------------------------
Write-Host "=== Installing dependencies ===" -ForegroundColor Cyan
$reqFile = Join-Path $ProjectRoot "requirements.txt"
if (-not (Test-Path $reqFile)) {
    Write-Host "  [FAIL] requirements.txt not found." -ForegroundColor Red
    pause
    exit 1
}
Write-Host "  Running: pip install -r requirements.txt" -ForegroundColor Gray
& $VenvPip install -r $reqFile
Write-Host "  Dependencies OK" -ForegroundColor Green
Write-Host ""

# -----------------------------------------------------------------------------
# Step 3: Create required folders if they do not exist
# -----------------------------------------------------------------------------
Write-Host "=== Folders ===" -ForegroundColor Cyan
$folders = @(
    "chroma_db",
    "docs",
    "logs"
)
foreach ($dir in $folders) {
    $full = Join-Path $ProjectRoot $dir
    if (-not (Test-Path $full)) {
        New-Item -ItemType Directory -Path $full -Force | Out-Null
        Write-Host "  Created: $dir" -ForegroundColor Yellow
    }
}
Write-Host "  Folders OK" -ForegroundColor Green
Write-Host ""

# -----------------------------------------------------------------------------
# Step 4: Start Redis (Docker) - must publish port 6379 so app can connect
# -----------------------------------------------------------------------------
Write-Host "=== Starting Redis ===" -ForegroundColor Cyan
docker port redis-rag 6379 2>$null | Out-Null
if (-not $?) {
    Write-Host "  Removing redis-rag (port 6379 not mapped); recreating..." -ForegroundColor Yellow
    docker rm -f redis-rag 2>$null
}
$redis = docker start redis-rag 2>$null
if (-not $?) {
    Write-Host "  Creating redis-rag container (port 6379, volume redis-rag-data)..." -ForegroundColor Yellow
    docker run -d --name redis-rag -p 6379:6379 -v redis-rag-data:/data redis:7-alpine
}
Write-Host "  Redis OK (port 6379)" -ForegroundColor Green
Start-Sleep -Seconds 2
Write-Host ""

# -----------------------------------------------------------------------------
# Step 5: Start API (uvicorn) in new window
# -----------------------------------------------------------------------------
Write-Host "=== Starting application ===" -ForegroundColor Cyan
Write-Host "  Starting API (uvicorn) in new window..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList @(
    "-NoExit",
    "-Command",
    "Set-Location '$ProjectRoot'; Write-Host 'API - close this window to stop' -ForegroundColor Cyan; & '$VenvPython' -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000"
)
Write-Host "  API starting (wait for 'Static PDF loaded' in that window)." -ForegroundColor Green
Start-Sleep -Seconds 6

# -----------------------------------------------------------------------------
# Step 6: Start Streamlit in new window
# -----------------------------------------------------------------------------
Write-Host "  Starting Streamlit UI in new window..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList @(
    "-NoExit",
    "-Command",
    "Set-Location '$ProjectRoot'; Write-Host 'Streamlit - close this window to stop' -ForegroundColor Cyan; & '$VenvPython' -m streamlit run ui/streamlit_app.py"
)
Write-Host "  Streamlit starting." -ForegroundColor Green
Write-Host ""

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
Write-Host "=== Ready ===" -ForegroundColor Cyan
Write-Host "  API:       http://127.0.0.1:8000" -ForegroundColor White
Write-Host "  Streamlit: http://localhost:8501" -ForegroundColor White
Write-Host ""
$staticPdf = Join-Path $ProjectRoot "docs\Essay on Narendra Modi.pdf"
if (-not (Test-Path $staticPdf)) {
    Write-Host "  [WARN] Static PDF not found: docs\Essay on Narendra Modi.pdf" -ForegroundColor Yellow
    Write-Host "  Copy your PDF there or set STATIC_PDF_PATH in .env" -ForegroundColor Gray
} else {
    Write-Host "  Static PDF: docs\Essay on Narendra Modi.pdf" -ForegroundColor Gray
}
Write-Host "  Add .env with Azure OpenAI keys (see .env.example if present)." -ForegroundColor Gray
Write-Host ""
Write-Host "  Close the API and Streamlit windows to stop the app." -ForegroundColor Gray
Write-Host ""
