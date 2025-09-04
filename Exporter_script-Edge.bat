@echo off
setlocal

:: Get the path to the project root (where this .bat file is located)
set "projectRoot=%~dp0"

:: Build the path to the PowerShell script
set "scriptPath=%projectRoot%scripts\Exporter_script.ps1"

:: Check if the PowerShell script exists
if not exist "%scriptPath%" (
    echo PowerShell script not found!
    pause
    exit /b
)

:: Display the script path for verification
echo Script path: %scriptPath%

:: Run PowerShell script with browser parameter (Edge)
pwsh.exe -ExecutionPolicy Bypass -File "%scriptPath%" -Browser Edge

endlocal