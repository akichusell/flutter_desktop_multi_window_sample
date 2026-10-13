@echo off
rem Runs watch_threads.ps1 without changing the execution policy. Ctrl+C to stop.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0watch_threads.ps1"
