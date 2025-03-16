#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting BadbeatsTools deployment...${NC}"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Docker Compose is not installed. Please install Docker Compose first.${NC}"
    exit 1
fi

# Create necessary directories
echo -e "${GREEN}Creating necessary directories...${NC}"
mkdir -p uploads
mkdir -p logs

# Check if .env file exists, if not create it
if [ ! -f .env ]; then
    echo -e "${YELLOW}Creating .env file...${NC}"
    cat > .env << EOL
FLASK_APP=server.py
FLASK_ENV=production
DATABASE_URL=postgresql://postgres:postgres@db:5432/badbeatstools
REDIS_URL=redis://redis:6379/0
SECRET_KEY=$(openssl rand -hex 32)
EOL
fi

# Stop any running containers
echo -e "${GREEN}Stopping any running containers...${NC}"
docker-compose down

# Build and start containers
echo -e "${GREEN}Building and starting containers...${NC}"
docker-compose up --build -d

# Wait for database to be ready
echo -e "${YELLOW}Waiting for database to be ready...${NC}"
sleep 10

# Run database migrations
echo -e "${GREEN}Running database migrations...${NC}"
docker-compose exec web flask db upgrade

# Check if services are running
echo -e "${GREEN}Checking service status...${NC}"
if docker-compose ps | grep -q "Up"; then
    echo -e "${GREEN}Deployment successful!${NC}"
    echo -e "${GREEN}The application is now running at http://localhost:8000${NC}"
    echo -e "${YELLOW}Default admin credentials:${NC}"
    echo -e "Email: admin@badbeatstools.com"
    echo -e "Password: admin123 (Please change this immediately!)"
else
    echo -e "${RED}Deployment failed. Please check the logs:${NC}"
    docker-compose logs
fi

# Print helpful commands
echo -e "\n${YELLOW}Useful commands:${NC}"
echo -e "- View logs: ${GREEN}docker-compose logs -f${NC}"
echo -e "- Stop application: ${GREEN}docker-compose down${NC}"
echo -e "- Restart application: ${GREEN}docker-compose restart${NC}"
echo -e "- Update application: ${GREEN}git pull && ./deploy.sh${NC}"

# Make the script executable
chmod +x deploy.sh
