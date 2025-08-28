@echo off
setlocal

REM Pull docker container
docker pull %REPO%:latest
if errorlevel 1 echo ERROR: Could not pull docker container %REPO%:latest

REM Drop CLI wrapper in the right place
echo @echo off > "%USERPROFILE%\%IMAGE%.bat"
echo docker run --rm -it -v "%%cd%%:/work" %REPO% %%* >> "%WINAPPS%\%IMAGE%.bat"

REM Report success
echo.
echo ^✓ metabuild installed: %USERPROFILE%\%IMAGE%.bat
echo.
echo Run "metabuild init" to get started.
echo.

endlocal
