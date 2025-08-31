@echo off
setlocal

set REPO=ghcr.io/frinknet/metabuild
set IMAGE=metabuild
set PREFIX=%USERPROFILE%\bin
set VER=%1
if "%VER%"=="" set VER=latest

REM Create PREFIX directory
if not exist "%PREFIX%" mkdir "%PREFIX%"

REM Add to PATH if not present
echo %PATH% | find /I "%PREFIX%" >nul
if errorlevel 1 (
    setx PATH "%PREFIX%;%PATH%" >nul
    echo PATH updated - please restart your terminal
)

REM Pull container with specified version
docker pull "%REPO%:%VER%"
if errorlevel 1 (
    echo ERROR: Could not pull docker container %REPO%:%VER%
    exit /b 1
)

REM Tag image - FIXED: Use %VER% not latest
docker tag "%REPO%:%VER%" "%IMAGE%"

REM Extract GitHub repo path
for /f "tokens=2,* delims=/" %%A in ("%REPO%") do set GITHUB_REPO=%%A/%%B

REM Create batch wrapper with version support
(
    echo @echo off
    echo set VER_INSTALLED=%VER%
    echo if "%%1"=="update" (
    echo     powershell -Command "iex (iwr 'https://github.com/%GITHUB_REPO%/raw/main/install.bat').Content" -- %%VER_INSTALLED%%
    echo     exit /b
    echo ^) else (
    echo     docker run --rm -it -v "%%cd%%:/build" %IMAGE% %%*
    echo ^)
) > "%PREFIX%\%IMAGE%.bat"

echo.
echo ✓ installed: %PREFIX%\%IMAGE%.bat (version: %VER%)
echo.
echo Run 'metabuild init' to get started.
echo.

endlocal
