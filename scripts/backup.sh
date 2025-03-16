#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
BACKUP_DIR="/var/backups/badbeatstools"
POSTGRES_CONTAINER="badbeatstools_db_1"
BACKUP_RETENTION_DAYS=7
DATE=$(date +%Y-%m-%d_%H-%M-%S)
S3_BUCKET="badbeatstools-backups"

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

echo -e "${YELLOW}Starting BadbeatsTools backup process...${NC}"

# Database backup
echo -e "${GREEN}Backing up PostgreSQL database...${NC}"
docker exec $POSTGRES_CONTAINER pg_dump -U postgres badbeatstools > "$BACKUP_DIR/db_backup_$DATE.sql"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Database backup completed successfully${NC}"
else
    echo -e "${RED}Database backup failed${NC}"
    exit 1
fi

# Compress database backup
gzip "$BACKUP_DIR/db_backup_$DATE.sql"

# Backup uploaded files
echo -e "${GREEN}Backing up uploaded files...${NC}"
tar -czf "$BACKUP_DIR/uploads_$DATE.tar.gz" /app/uploads
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Files backup completed successfully${NC}"
else
    echo -e "${RED}Files backup failed${NC}"
    exit 1
fi

# Backup configuration files
echo -e "${GREEN}Backing up configuration files...${NC}"
tar -czf "$BACKUP_DIR/config_$DATE.tar.gz" \
    /app/docker-compose.prod.yml \
    /app/nginx.prod.conf \
    /app/.env.prod \
    /app/monitoring
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Configuration backup completed successfully${NC}"
else
    echo -e "${RED}Configuration backup failed${NC}"
    exit 1
fi

# Upload to S3 (if AWS CLI is configured)
if command -v aws &> /dev/null; then
    echo -e "${GREEN}Uploading backups to S3...${NC}"
    aws s3 sync $BACKUP_DIR s3://$S3_BUCKET/$(date +%Y-%m-%d)/
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}S3 upload completed successfully${NC}"
    else
        echo -e "${RED}S3 upload failed${NC}"
    fi
fi

# Clean up old backups
echo -e "${GREEN}Cleaning up old backups...${NC}"
find $BACKUP_DIR -type f -mtime +$BACKUP_RETENTION_DAYS -delete

# Create backup report
REPORT="$BACKUP_DIR/backup_report_$DATE.txt"
echo "BadbeatsTools Backup Report - $DATE" > $REPORT
echo "----------------------------------------" >> $REPORT
echo "Database Backup: db_backup_$DATE.sql.gz" >> $REPORT
echo "Files Backup: uploads_$DATE.tar.gz" >> $REPORT
echo "Config Backup: config_$DATE.tar.gz" >> $REPORT
echo "Backup Location: $BACKUP_DIR" >> $REPORT
if command -v aws &> /dev/null; then
    echo "S3 Bucket: s3://$S3_BUCKET/$(date +%Y-%m-%d)/" >> $REPORT
fi
echo "----------------------------------------" >> $REPORT

# Send backup report via email
if [ -x "$(command -v mail)" ]; then
    cat $REPORT | mail -s "BadbeatsTools Backup Report - $DATE" admin@badbeatstools.io
fi

echo -e "${GREEN}Backup process completed successfully${NC}"
echo -e "${YELLOW}Backup report saved to: $REPORT${NC}"

# Make the script executable
chmod +x backup.sh
