#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting BadbeatsTools...${NC}"

# Make deploy script executable
chmod +x deploy.sh

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo -e "${GREEN}Creating virtual environment...${NC}"
    python3 -m venv venv
fi

# Activate virtual environment
echo -e "${GREEN}Activating virtual environment...${NC}"
source venv/bin/activate

# Install requirements
echo -e "${GREEN}Installing requirements...${NC}"
pip install -r requirements.txt

# Run tests
echo -e "${YELLOW}Running tests...${NC}"
python3 test.py

# Check if port 8000 is in use
if lsof -Pi :8000 -sTCP:LISTEN -t >/dev/null ; then
    echo -e "${YELLOW}Port 8000 is in use. Stopping existing process...${NC}"
    pkill -f "python3 -m http.server 8000"
fi

# Start the application
echo -e "${GREEN}Starting the application...${NC}"
python3 server.py

# Make the script executable
chmod +x start.sh

echo -e "${GREEN}Application is running at http://localhost:8000${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop the application${NC}"
