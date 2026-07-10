@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Uninstall.ps1"
if errorlevel 1 (
  echo.
  echo Uninstall failed. See the message above.
  pause
)
endlocal
