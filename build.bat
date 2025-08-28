@echo off
REM METABUILD - (c) 2025 FRINKnet & Friends - 0BSD

REM THIS REPO
set REPO=frinknet/metabuild
for /f "delims=/" %%i in ("%REPO%") do set IMAGE=%%i
set WORKDIR=%cd%

REM MAKE SURE WE HAVE A CONTAINER
docker image inspect %IMAGE% >nul 2>&1
if errorlevel 1 (
  docker pull %REPO%:latest >nul 2>&1

  if errorlevel 1 (
    echo ^>^>^> Building Docker Image: %IMAGE%
    docker build -t %IMAGE% .
  ) else (
    docker tag %REPO%:latest %IMAGE%
  )
)

REM MAKE SURE WE HAVE A CONTAINER
docker run --rm -it -v "%WORKDIR%:/work" %IMAGE% %*
