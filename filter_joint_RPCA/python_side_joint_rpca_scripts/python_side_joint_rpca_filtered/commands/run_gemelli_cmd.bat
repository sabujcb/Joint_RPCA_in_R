@echo off
setlocal enabledelayedexpansion

REM Usage:
REM   commands\run_gemelli_cmd.bat
REM   commands\run_gemelli_cmd.bat "D:\Mia Folder" mia-gemelli

set "PROJECT_DIR=%~1"
if "%PROJECT_DIR%"=="" set "PROJECT_DIR=D:\Mia Folder"

set "CONDA_ENV_NAME=%~2"
if "%CONDA_ENV_NAME%"=="" set "CONDA_ENV_NAME=mia-gemelli"

echo Project directory: %PROJECT_DIR%
echo Conda environment: %CONDA_ENV_NAME%

call conda activate %CONDA_ENV_NAME%
if errorlevel 1 exit /b 1

python "%PROJECT_DIR%\python\check_gemelli_environment.py"
if errorlevel 1 exit /b 1

python "%PROJECT_DIR%\python\run_gemelli_joint_rpca.py" --project-dir "%PROJECT_DIR%"
if errorlevel 1 exit /b 1

endlocal
