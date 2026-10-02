@echo off
setlocal
cd /d "%~dp0"

echo Checkout session
echo.
echo The slot id is unique and must be 4 characters. The branch will be uppercase, for example A002-101010.
echo You will be asked for the slot id first, then the scenario (a, b, c, or d).
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0checkout-session.ps1"
echo.
pause
endlocal
