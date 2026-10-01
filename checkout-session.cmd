@echo off
setlocal
cd /d "%~dp0"

echo Checkout session
echo.
set "SCENARIO="
set "SLOTID="

set /p SCENARIO=Scenario (a, b, c, or d): 
set /p SLOTID=Slot id, exactly 4 characters (for example A002): 

if "%SCENARIO%"=="" (
    echo Scenario is required.
    echo.
    pause
    exit /b 1
)
if "%SLOTID%"=="" (
    echo Slot id is required.
    echo.
    pause
    exit /b 1
)

echo.
echo Scenario: scenario-%SCENARIO% from origin
echo The slot id is unique and must be 4 characters. The branch will be uppercase, for example A002-101010.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0checkout-session.ps1" -Problem "%SCENARIO%" -SlotId "%SLOTID%"
echo.
pause
endlocal
