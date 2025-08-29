@echo off
setlocal

set REPO=ghcr.io/frinknet/metabuild
for %%A in (%REPO%) do set IMAGE=metabuild
set PREFIX=%USERPROFILE%\bin

REM Ensure PREFIX exists (mkdir equivalent)
if not exist "%PREFIX%" mkdir "%PREFIX%"

REM Check if PREFIX in PATH
echo %PATH% | find /I "%PREFIX%" >nul
if errorlevel 1 (
    echo set PATH=%PREFIX%;%%PATH%%>>"%USERPROFILE%\add_to_path.bat"
    call "%USERPROFILE%\add_to_path.bat"
)

REM Pull container
docker pull %REPO%:latest
if errorlevel 1 (
    echo ERROR: Could not pull docker container %REPO%:latest
    exit /b 1
)

REM Tag image (simply same name on Windows, adjust if needed)
docker tag %REPO%:latest %IMAGE%

REM Extract GitHub repo path once
for /f "tokens=2,* delims=/" %%A in ("%REPO%") do set GITHUB_REPO=%%A/%%B

REM Create a shell wrapper batch file
(
    echo @echo off
    echo if "%%1"=="update" (
    echo     powershell -Command "iex (iwr https://github.com/%GITHUB_REPO%/raw/main/install.bat).Content"
    echo     exit /b
    echo )
    echo docker run --rm -it -v "%%cd%%:/build" %IMAGE% %%*
) > "%PREFIX%\%IMAGE%.bat"

REM Make executable is automatic for batch (just ensure written)

REM Report
echo.
echo ^✓ installed: %PREFIX%\%IMAGE%.bat
echo.
echo Run "metabuild init" to get started.
echo.

endlocal
