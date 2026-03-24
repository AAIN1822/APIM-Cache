# Start all RAG app services: Redis, API (uvicorn), Streamlit UI.
# Run from anywhere:  & "D:\agent\azure-rag-app_final\azure-rag-app\start_all.ps1"
# Or double-click start_all.cmd

$ProjectRoot = $PSScriptRoot
$VenvPython = Join-Path $ProjectRoot ".venv\Scripts\python.exe"
if (Test-Path $VenvPython) { $Python = $VenvPython } else { $Python = "D:\envv\Scripts\python.exe" }

Write-Host "=== Pre-check ===" -ForegroundColor Cyan
$fail = $false
if (-not (Test-Path $Python)) {
    Write-Host "  Python not found: $Python" -ForegroundColor Red
    Write-Host "  Run setup_and_run.bat once to create .venv, or use D:\envv" -ForegroundColor Yellow
    $fail = $true
} else { Write-Host "  Python OK ($(if (Test-Path $VenvPython) { '.venv' } else { 'D:\envv' }))" -ForegroundColor Green }
$docker = docker info 2>$null; if (-not $?) {
    Write-Host "  Docker not running. Start Docker Desktop and try again." -ForegroundColor Red
    $fail = $true
} else { Write-Host "  Docker OK" -ForegroundColor Green }
$pdf = Join-Path $ProjectRoot "docs\Essay on Narendra Modi.pdf"
if (-not (Test-Path $pdf)) {
    Write-Host "  Static PDF not found: docs\Essay on Narendra Modi.pdf" -ForegroundColor Yellow
    Write-Host "  (API may fail at startup if STATIC_PDF_PATH is wrong)" -ForegroundColor Gray
} else { Write-Host "  Static PDF OK" -ForegroundColor Green }
if ($fail) {
    Write-Host "`nFix the issues above, then run again." -ForegroundColor Red
    pause
    exit 1
}
Write-Host ""

Write-Host "=== Starting RAG services ===" -ForegroundColor Cyan

# 1) Redis (ensure port 6379 is published so the app can connect to localhost:6379)
Write-Host "1. Redis..." -ForegroundColor Yellow
docker port redis-rag 6379 2>$null | Out-Null
if (-not $?) {
    Write-Host "   Removing redis-rag (no port 6379 mapped); will recreate with -p 6379:6379"
    docker rm -f redis-rag 2>$null
}
$redis = docker start redis-rag 2>$null
if (-not $?) {
    Write-Host "   Creating and starting redis-rag container (port 6379, volume redis-rag-data)..."
    docker run -d --name redis-rag -p 6379:6379 -v redis-rag-data:/data redis:7-alpine
}
if ($?) { Write-Host "   Redis OK (port 6379)" -ForegroundColor Green } else { Write-Host "   Redis failed (is Docker running?)" -ForegroundColor Red }
Start-Sleep -Seconds 2

# 2) API (uvicorn) - new window
Write-Host "2. API (uvicorn)..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList @(
    "-NoExit",
    "-Command",
    "Set-Location '$ProjectRoot'; Write-Host 'API - close this window to stop' -ForegroundColor Cyan; & '$Python' -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000"
)
Write-Host "   API starting in new window (wait for 'Static PDF loaded' there)" -ForegroundColor Green
Start-Sleep -Seconds 6

# 3) Streamlit - new window
Write-Host "3. Streamlit UI..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList @(
    "-NoExit",
    "-Command",
    "Set-Location '$ProjectRoot'; Write-Host 'Streamlit - close this window to stop' -ForegroundColor Cyan; & '$Python' -m streamlit run ui/streamlit_app.py"
)
Write-Host "   Streamlit starting in new window" -ForegroundColor Green

Write-Host ""
Write-Host "=== All services started ===" -ForegroundColor Cyan
Write-Host "  API:       http://127.0.0.1:8000" -ForegroundColor White
Write-Host "  Chunks:    http://127.0.0.1:8000/api/chunks" -ForegroundColor White
Write-Host "  Streamlit: http://localhost:8501" -ForegroundColor White
Write-Host ""
Write-Host "Close the API and Streamlit windows to stop those services." -ForegroundColor Gray
