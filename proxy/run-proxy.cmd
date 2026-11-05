@echo off
rem dsh-claude-mem-kit — start the observer bridge in the foreground.
rem MIT License, Copyright (c) 2026 GreenJenckens.
setlocal
cd /d "%~dp0"

where node >nul 2>nul
if errorlevel 1 (
  echo [dsh-claude-mem-kit] Node.js 20+ is required and was not found on PATH.
  exit /b 1
)

if not exist "%USERPROFILE%\.claude-mem" mkdir "%USERPROFILE%\.claude-mem"

rem Optional overrides:
rem   set OC_PROXY_PORT=37901
rem   set OC_PROXY_UPSTREAM=https://opencode.ai
rem   set OC_PROXY_MODEL=deepseek-v4.1-flash

node "%~dp0server.mjs" >> "%USERPROFILE%\.claude-mem\proxy.log" 2>&1
