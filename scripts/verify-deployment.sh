#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

DOMAIN="badbeatstools.io"
ENDPOINTS=(
    "/"
    "/api/tracks"
    "/api/auth/login"
    "/metrics"
)

echo -e "${YELLOW}Starting deployment verification for BadbeatsTools...${NC}"

# Function to check HTTP status
check_endpoint() {
    local url=$1
    local expected_status=$2
    local response=$(curl -s -o /dev/null -w "%{http_code}" "$url")
    
    if [ "$response" = "$expected_status" ]; then
        echo -e "${GREEN}✓ $url - Status: $response${NC}"
        return 0
    else
        echo -e "${RED}✗ $url - Expected: $expected_status, Got: $response${NC}"
        return 1
    fi
}

# Function to check SSL certificate
check_ssl() {
    local domain=$1
    echo -e "\n${YELLOW}Checking SSL certificate for $domain...${NC}"
    
    ssl_info=$(curl -vI "https://$domain" 2>&1 | grep "SSL certificate")
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ SSL certificate is valid${NC}"
        echo "$ssl_info"
    else
        echo -e "${RED}✗ SSL certificate check failed${NC}"
        return 1
    fi
}

# Function to check Docker containers
check_containers() {
    echo -e "\n${YELLOW}Checking Docker containers...${NC}"
    
    containers=(
        "web"
        "db"
        "redis"
        "nginx"
        "prometheus"
        "grafana"
        "alertmanager"
        "loki"
    )
    
    for container in "${containers[@]}"; do
        if docker ps | grep -q "$container"; then
            echo -e "${GREEN}✓ $container is running${NC}"
        else
            echo -e "${RED}✗ $container is not running${NC}"
            return 1
        fi
    done
}

# Function to check database connection
check_database() {
    echo -e "\n${YELLOW}Checking database connection...${NC}"
    
    if docker exec badbeatstools_db_1 pg_isready -U postgres; then
        echo -e "${GREEN}✓ Database connection successful${NC}"
    else
        echo -e "${RED}✗ Database connection failed${NC}"
        return 1
    fi
}

# Function to check Redis connection
check_redis() {
    echo -e "\n${YELLOW}Checking Redis connection...${NC}"
    
    if docker exec badbeatstools_redis_1 redis-cli ping | grep -q "PONG"; then
        echo -e "${GREEN}✓ Redis connection successful${NC}"
    else
        echo -e "${RED}✗ Redis connection failed${NC}"
        return 1
    fi
}

# Function to check monitoring stack
check_monitoring() {
    echo -e "\n${YELLOW}Checking monitoring services...${NC}"
    
    services=(
        "http://localhost:9090/api/v1/status/runtimeinfo" # Prometheus
        "http://localhost:3000/api/health" # Grafana
        "http://localhost:9093/-/healthy" # AlertManager
        "http://localhost:3100/ready" # Loki
    )
    
    for service in "${services[@]}"; do
        if curl -s "$service" > /dev/null; then
            echo -e "${GREEN}✓ $(echo $service | cut -d'/' -f3) is healthy${NC}"
        else
            echo -e "${RED}✗ $(echo $service | cut -d'/' -f3) health check failed${NC}"
            return 1
        fi
    done
}

# Function to check disk space
check_disk_space() {
    echo -e "\n${YELLOW}Checking disk space...${NC}"
    
    usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$usage" -lt 90 ]; then
        echo -e "${GREEN}✓ Disk space usage: $usage%${NC}"
    else
        echo -e "${RED}✗ High disk space usage: $usage%${NC}"
        return 1
    fi
}

# Main verification process
echo -e "\n${YELLOW}1. Checking endpoints...${NC}"
for endpoint in "${ENDPOINTS[@]}"; do
    check_endpoint "https://$DOMAIN$endpoint" 200
done

check_ssl $DOMAIN
check_containers
check_database
check_redis
check_monitoring
check_disk_space

# Check backup configuration
echo -e "\n${YELLOW}Checking backup configuration...${NC}"
if [ -f "/etc/cron.d/badbeatstools-backup" ]; then
    echo -e "${GREEN}✓ Backup cron job is configured${NC}"
else
    echo -e "${RED}✗ Backup cron job is not configured${NC}"
fi

# Final report
echo -e "\n${YELLOW}Deployment Verification Report${NC}"
echo -e "----------------------------------------"
echo -e "Domain: $DOMAIN"
echo -e "Environment: Production"
echo -e "Timestamp: $(date)"
echo -e "----------------------------------------"

# Check if any errors occurred
if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✓ All checks passed successfully!${NC}"
else
    echo -e "\n${RED}✗ Some checks failed. Please review the output above.${NC}"
fi

# Make the script executable
chmod +x verify-deployment.sh
