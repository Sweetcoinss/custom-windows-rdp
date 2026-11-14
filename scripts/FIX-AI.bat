@echo off
title FIX AI - One Click Fix
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0fix-ai.ps1"
echo.
echo Press any key to exit...
pause >nul
