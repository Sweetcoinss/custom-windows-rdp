@echo off
title OpenCode Launcher
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-opencode.ps1" %*
