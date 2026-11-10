@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run.ps1" -Editor
if errorlevel 1 pause
