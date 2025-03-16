#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
BACKUP_DIR="/var/backups/badbeatstools"
POSTGRES_CONTAINER="badbeatstools_db_1"
RESTORE_DIR="/tmp/badbeatstools_restore"
S3_BUCKET="badbeatstools-backups"

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -d, --date DATE    Specify backup date to restore (YYYY-MM-DD_HH-MM-SS)"
    echo "  -l, --latest       Restore latest backup"
    echo "  -s, --s3           Restore from S3 backup"
    echo "  -h, --help         Display this help message"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -d|--date)
            BACKUP_DATE="$2"
            shift
            shift
            ;;
        -l|--latest)
            LATEST=true
            shift
            ;;
        -s|--s3)
            FROM_S3=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            usage
            ;;
    esac
done

# Create restore directory
mkdir -p $RESTORE_DIR

echo -e "${YELLOW}Starting BadbeatsTools restore process...${NC}"

# If restoring from S3
if [ "$FROM_S3" = true ]; then
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}AWS CLI is not installed. Cannot restore from S3.${NC}"
        exit 1
    fi

    if [ "$LATEST" = true ]; then
        # Get latest backup date from S3
        BACKUP_DATE=$(aws s3 ls s3://$S3_BUCKET/ | sort | tail -n 1 | awk '{print $2}' | sed 's/\///')
    fi

    echo -e "${GREEN}Downloading backups from S3...${NC}"
    aws s3 sync s3://$S3_BUCKET/$BACKUP_DATE $RESTORE_DIR/
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to download backups from S3${NC}"
        exit 1
    fi
else
    # If using latest local backup
    if [ "$LATEST" = true ]; then
        BACKUP_DATE=$(ls -t $BACKUP_DIR/db_backup_* | head -n1 | sed 's/.*db_backup_\(.*\)\.sql\.gz/\1/')
    fi

    # Copy backup files to restore directory
    cp $BACKUP_DIR/db_backup_$BACKUP_DATE.sql.gz $RESTORE_DIR/
    cp $BACKUP_DIR/uploads_$BACKUP_DATE.tar.gz $RESTORE_DIR/
    cp $BACKUP_DIR/config_$BACKUP_DATE.tar.gz $RESTORE_DIR/
fi

echo -e "${GREEN}Using backup from: $BACKUP_DATE${NC}"

# Stop application containers
echo -e "${YELLOW}Stopping application containers...${NC}"
docker-compose -f docker-compose.prod.yml down

# Restore database
echo -e "${GREEN}Restoring database...${NC}"
gunzip -c $RESTORE_DIR/db_backup_$BACKUP_DATE.sql.gz > $RESTORE_DIR/db_backup.sql
docker exec -i $POSTGRES_CONTAINER psql -U postgres -d badbeatstools < $RESTORE_DIR/db_backup.sql
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Database restored successfully${NC}"
else
    echo -e "${RED}Database restore failed${NC}"
    exit 1
fi

# Restore uploaded files
echo -e "${GREEN}Restoring uploaded files...${NC}"
tar -xzf $RESTORE_DIR/uploads_$BACKUP_DATE.tar.gz -C /
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Files restored successfully${NC}"
else
    echo -e "${RED}Files restore failed${NC}"
    exit 1
fi

# Restore configuration files
echo -e "${GREEN}Restoring configuration files...${NC}"
tar -xzf $RESTORE_DIR/config_$BACKUP_DATE.tar.gz -C /
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Configuration restored successfully${NC}"
else
    echo -e "${RED}Configuration restore failed${NC}"
    exit 1
fi

# Start application containers
echo -e "${GREEN}Starting application containers...${NC}"
docker-compose -f docker-compose.prod.yml up -d

# Clean up restore directory
rm -rf $RESTORE_DIR

# Create restore report
REPORT="$BACKUP_DIR/restore_report_$(date +%Y-%m-%d_%H-%M-%S).txt"
echo "BadbeatsTools Restore Report" > $REPORT
echo "----------------------------------------" >> $REPORT
echo "Restore Date: $(date)" >> $REPORT
echo "Backup Used: $BACKUP_DATE" >> $REPORT
if [ "$FROM_S3" = true ]; then
    echo "Restored from: s3://$S3_BUCKET/$BACKUP_DATE/" >> $REPORT
else
    echo "Restored from: $BACKUP_DIR" >> $REPORT
fi
echo "----------------------------------------" >> $REPORT

# Send restore report via email
if [ -x "$(command -v mail)" ]; then
    cat $REPORT | mail -s "BadbeatsTools Restore Report - $(date +%Y-%m-%d)" admin@badbeatstools.io
fi

echo -e "${GREEN}Restore process completed successfully${NC}"
echo -e "${YELLOW}Restore report saved to: $REPORT${NC}"

# Make the script executable
chmod +x restore.sh
