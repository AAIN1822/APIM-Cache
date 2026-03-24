@echo off
REM Start all RAG services (Redis, API, Streamlit). Single command.
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0start_all.ps1"
pause
