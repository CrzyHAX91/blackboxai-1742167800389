#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="badbeatstools.io"
EMAIL="admin@badbeatstools.io"

echo -e "${YELLOW}Starting BadbeatsTools production deployment...${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Check requirements
command -v docker >/dev/null 2>&1 || { echo -e "${RED}Docker is required but not installed.${NC}" >&2; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo -e "${RED}Docker Compose is required but not installed.${NC}" >&2; exit 1; }

# Create necessary directories
echo -e "${GREEN}Creating necessary directories...${NC}"
mkdir -p certbot/conf
mkdir -p certbot/www
mkdir -p uploads
mkdir -p logs
mkdir -p static

# Create production environment file if it doesn't exist
if [ ! -f .env.prod ]; then
    echo -e "${YELLOW}Creating production environment file...${NC}"
    cat > .env.prod << EOL
FLASK_APP=server.py
FLASK_ENV=production
DEBUG=False
DOMAIN_NAME=${DOMAIN}
DB_PASSWORD=$(openssl rand -hex 32)
SECRET_KEY=$(openssl rand -hex 32)
JWT_SECRET_KEY=$(openssl rand -hex 32)
REDIS_URL=redis://redis:6379/0
SSL_ENABLED=true
EOL
fi

# Stop any running containers
echo -e "${GREEN}Stopping any running containers...${NC}"
docker-compose -f docker-compose.prod.yml down

# Initialize SSL certificates
echo -e "${YELLOW}Initializing SSL certificates...${NC}"
if [ ! -d "certbot/conf/live/${DOMAIN}" ]; then
    echo -e "${GREEN}Obtaining SSL certificates...${NC}"
    
    # Start nginx for domain verification
    docker-compose -f docker-compose.prod.yml up -d nginx
    
    # Get SSL certificates
    docker-compose -f docker-compose.prod.yml run --rm certbot certonly \
        --webroot \
        --webroot-path /var/www/certbot \
        --email $EMAIL \
        --agree-tos \
        --no-eff-email \
        -d $DOMAIN \
        -d www.$DOMAIN

    # Stop nginx after obtaining certificates
    docker-compose -f docker-compose.prod.yml stop nginx
fi

# Build and start containers
echo -e "${GREEN}Building and starting containers...${NC}"
docker-compose -f docker-compose.prod.yml up --build -d

# Wait for database to be ready
echo -e "${YELLOW}Waiting for database to be ready...${NC}"
sleep 15

# Run database migrations
echo -e "${GREEN}Running database migrations...${NC}"
docker-compose -f docker-compose.prod.yml exec web flask db upgrade

# Set up automatic SSL renewal
echo -e "${GREEN}Setting up automatic SSL renewal...${NC}"
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/docker-compose -f /root/badbeatstools/docker-compose.prod.yml run --rm certbot renew --quiet") | crontab -

# Check if services are running
echo -e "${GREEN}Checking service status...${NC}"
if docker-compose -f docker-compose.prod.yml ps | grep -q "Up"; then
    echo -e "${GREEN}Deployment successful!${NC}"
    echo -e "${GREEN}The application is now running at https://${DOMAIN}${NC}"
    
    # Print important information
    echo -e "\n${YELLOW}Important Information:${NC}"
    echo -e "- Website URL: ${GREEN}https://${DOMAIN}${NC}"
    echo -e "- Admin Panel: ${GREEN}https://${DOMAIN}/admin${NC}"
    echo -e "- SSL Certificate Path: ${GREEN}/etc/letsencrypt/live/${DOMAIN}${NC}"
    echo -e "- SSL Auto-renewal: ${GREEN}Configured (runs daily at 12:00)${NC}"
else
    echo -e "${RED}Deployment failed. Please check the logs:${NC}"
    docker-compose -f docker-compose.prod.yml logs
fi

# Print helpful commands
echo -e "\n${YELLOW}Useful Commands:${NC}"
echo -e "- View logs: ${GREEN}docker-compose -f docker-compose.prod.yml logs -f${NC}"
echo -e "- Restart services: ${GREEN}docker-compose -f docker-compose.prod.yml restart${NC}"
echo -e "- Stop services: ${GREEN}docker-compose -f docker-compose.prod.yml down${NC}"
echo -e "- Update application: ${GREEN}git pull && ./deploy-prod.sh${NC}"

# Security recommendations
echo -e "\n${YELLOW}Security Recommendations:${NC}"
echo -e "1. Update all default passwords in .env.prod"
echo -e "2. Configure firewall rules"
echo -e "3. Set up regular backups"
echo -e "4. Monitor system logs"
echo -e "5. Keep all packages updated"

# Make the script executable
chmod +x deploy-prod.sh
