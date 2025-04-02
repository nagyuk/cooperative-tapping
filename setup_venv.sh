#!/bin/bash
# Setup script for creating a Python virtual environment for the project

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Setting up virtual environment for Cooperative Tapping Task...${NC}"

# Check Python version
python_version=$(python3 --version 2>&1 | awk '{print $2}')
python_major=$(echo $python_version | cut -d. -f1)
python_minor=$(echo $python_version | cut -d. -f2)

if [ "$python_major" -lt 3 ] || [ "$python_major" -eq 3 -a "$python_minor" -lt 9 ]; then
    echo -e "${RED}Error: Python 3.9 or newer is required. Found $python_version${NC}"
    echo "Please install Python 3.9+ and try again."
    exit 1
fi

echo -e "${GREEN}Using Python $python_version${NC}"

# Create virtual environment
venv_name="venv_py${python_major}${python_minor}"
echo -e "${YELLOW}Creating virtual environment: $venv_name${NC}"

python3 -m venv $venv_name

if [ ! -d "$venv_name" ]; then
    echo -e "${RED}Failed to create virtual environment.${NC}"
    exit 1
fi

# Activate virtual environment
echo -e "${YELLOW}Activating virtual environment...${NC}"
source $venv_name/bin/activate

# Update pip
echo -e "${YELLOW}Upgrading pip...${NC}"
pip install --upgrade pip

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
pip install -r requirements.txt

# Install the package in development mode
echo -e "${YELLOW}Installing package in development mode...${NC}"
pip install -e .

echo -e "${GREEN}Virtual environment setup complete!${NC}"
echo -e "To activate the virtual environment, run: ${YELLOW}source $venv_name/bin/activate${NC}"
echo -e "To deactivate, run: ${YELLOW}deactivate${NC}"