@echo off
cd /d "%~dp0"
set "BUNDLED_PYTHON=C:\Users\user\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
if exist "%BUNDLED_PYTHON%" (
  "%BUNDLED_PYTHON%" serve.py
) else (
  python serve.py
)
pause
