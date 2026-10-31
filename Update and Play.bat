@echo off
rem Purrmiere: get the latest and play. Double-click this.
setlocal
set HERE=%~dp0
powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%HERE%tools\updater.ps1"
endlocal
