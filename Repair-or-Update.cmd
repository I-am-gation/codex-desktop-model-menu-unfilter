@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Install.ps1" -Repair
if errorlevel 1 (
  echo.
  echo Repair failed. See the message above.
  pause
)
endlocal
