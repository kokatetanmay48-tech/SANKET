@echo off
title SANKET C2 Local Server
cd /d "%~dp0"
echo ========================================================
echo Starting SANKET Local Web Server...
echo URL: http://localhost:8080/
echo ========================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1" -Port 8080 -OpenBrowser
pause
