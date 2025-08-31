@echo off
setlocal

set "REPO=ghcr.io/frinknet/metabuild"
set "IMAGE=metabuild"
set "PREFIX=%USERPROFILE%\bin"
set "VER=%~1"
if "%VER%"=="" set "VER=latest"

REM Create PREFIX
if not exist "%PREFIX%" mkdir "%PREFIX%"

REM Add to PATH if not present (new shells only)
echo %PATH% | find /I "%PREFIX%" >nul
if errorlevel 1 (
  setx PATH "%PREFIX%;%PATH%" >nul
  echo PATH updated - restart terminal to load it
)

REM Previous local alias ID (if any)
set "OLD_ID="
for /f "usebackq delims=" %%I in (`docker image inspect -f "{{.Id}}" "%IMAGE%:latest" 2^>nul`) do set "OLD_ID=%%I"

REM Pull new image
docker image pull "%REPO%:%VER%"
if errorlevel 1 (
  echo ERROR: Could not pull docker image %REPO%:%VER%
  exit /b 1
)

REM Retag to stable local alias
docker image tag "%REPO%:%VER%" "%IMAGE%:latest"

REM New ID
set "NEW_ID="
for /f "usebackq delims=" %%I in (`docker image inspect -f "{{.Id}}" "%IMAGE%:latest"`) do set "NEW_ID=%%I"

REM Remove prior image ID if changed (ignored if referenced)
if defined OLD_ID if not "%OLD_ID%"=="%NEW_ID%" (
  docker image rm "%OLD_ID%" >nul 2>&1
)

REM Opportunistic cleanup of dangling layers
docker image prune -f >nul 2>&1

REM Extract GitHub repo path (owner/name)
for /f "tokens=2,* delims=/" %%A in ("%REPO%") do set "GITHUB_REPO=%%A/%%B"

REM Create batch wrapper
> "%PREFIX%\%IMAGE%.bat" (
  echo @echo off
  echo setlocal
  echo set "IMAGE=%IMAGE%:latest"
  echo set "VER_INSTALLED=%VER%"
  echo if "%%~1"=="update" (
  echo   curl -fsSL "https://github.com/%GITHUB_REPO%/raw/main/install.bat" -o "%%TEMP%%\metabuild-install.bat"
  echo   if errorlevel 1 echo ERROR: update fetch failed&& exit /b 1
  echo   call "%%TEMP%%\metabuild-install.bat" "%%VER_INSTALLED%%"
  echo   exit /b
  echo ^)
  echo docker run --rm -it -v "%%cd%%:/build" "%%IMAGE%%" %%*
  echo endlocal
)

echo.
echo ^✓ installed: %PREFIX%\%IMAGE%.bat (version: %VER%)
echo.
echo Run 'metabuild init' to get started.
echo.

endlocal

