# Run FastAPI with the Python that has redis (d:\envv).
# Use this if your default (envv) points to another venv (e.g. InterTek Backend).
$PythonWithRedis = "D:\envv\Scripts\python.exe"
if (-not (Test-Path $PythonWithRedis)) {
    Write-Host "Not found: $PythonWithRedis - edit run_server.ps1 and set PythonWithRedis to your venv that has redis."
    exit 1
}
& $PythonWithRedis -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
