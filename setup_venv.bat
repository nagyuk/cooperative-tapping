@echo off
:: Setup script for creating a Python virtual environment for the project on Windows

echo Setting up virtual environment for Cooperative Tapping Task...

:: Check Python version
for /f "tokens=2" %%V in ('python --version 2^>^&1') do set python_version=%%V
for /f "tokens=1 delims=." %%M in ("%python_version%") do set python_major=%%M
for /f "tokens=2 delims=." %%m in ("%python_version%") do set python_minor=%%m

if %python_major% LSS 3 (
    echo Error: Python 3.9 or newer is required. Found %python_version%
    echo Please install Python 3.9+ and try again.
    exit /b 1
)

if %python_major% EQU 3 (
    if %python_minor% LSS 9 (
        echo Error: Python 3.9 or newer is required. Found %python_version%
        echo Please install Python 3.9+ and try again.
        exit /b 1
    )
)

echo Using Python %python_version%

:: Create virtual environment
set venv_name=venv_py%python_major%%python_minor%
echo Creating virtual environment: %venv_name%

python -m venv %venv_name%

if not exist %venv_name% (
    echo Failed to create virtual environment.
    exit /b 1
)

:: Activate virtual environment
echo Activating virtual environment...
call %venv_name%\Scripts\activate.bat

:: Update pip
echo Upgrading pip...
pip install --upgrade pip

:: Install dependencies
echo Installing dependencies...
pip install -r requirements.txt

:: Install the package in development mode
echo Installing package in development mode...
pip install -e .

echo Virtual environment setup complete!
echo To activate the virtual environment, run: %venv_name%\Scripts\activate.bat
echo To deactivate, run: deactivate