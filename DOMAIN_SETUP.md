# Domain Setup and Deployment Guide for BadbeatsTools.io

This guide walks you through setting up your domain and deploying BadbeatsTools to production.

## 1. Domain Registration

1. Purchase the domain (badbeatstools.io) from a domain registrar:
   - Visit [Name.com](https://www.name.com) or [Namecheap](https://www.namecheap.com)
   - Search for your desired .io domain
   - Complete the purchase

## 2. DNS Configuration

### A. Set up DNS Records:

1. Create A records:
```
Type  Name                     Value               TTL
A     badbeatstools.io        <your-server-ip>    3600
A     www.badbeatstools.io    <your-server-ip>    3600
```

2. Create additional records for subdomains:
```
Type  Name                     Value               TTL
A     cdn.badbeatstools.io    <your-cdn-ip>       3600
A     api.badbeatstools.io    <your-server-ip>    3600
```

### B. Set up Email Records (Optional):

```
Type   Name                    Value                                TTL
MX     badbeatstools.io       10 mail.badbeatstools.io            3600
TXT    badbeatstools.io       v=spf1 include:_spf.google.com ~all 3600
```

## 3. Server Setup

### A. Provision a Server:

1. Choose a cloud provider:
   - DigitalOcean
   - AWS
   - Google Cloud
   - Linode

2. Minimum recommended specifications:
   - 2 CPU cores
   - 4GB RAM
   - 60GB SSD
   - Ubuntu 20.04 LTS

### B. Initial Server Setup:

1. SSH into your server:
```bash
ssh root@your-server-ip
```

2. Update system packages:
```bash
apt update && apt upgrade -y
```

3. Install required packages:
```bash
apt install -y docker.io docker-compose nginx certbot python3-certbot-nginx
```

4. Configure firewall:
```bash
ufw allow 22
ufw allow 80
ufw allow 443
ufw enable
```

## 4. Application Deployment

### A. Clone Repository:

```bash
git clone https://github.com/yourusername/badbeatstools.git
cd badbeatstools
```

### B. Configure Environment:

1. Update `.env.prod` with your settings:
```bash
nano .env.prod
```

2. Update domain in `nginx.prod.conf`:
```bash
nano nginx.prod.conf
```

### C. Deploy Application:

1. Make deployment script executable:
```bash
chmod +x deploy-prod.sh
```

2. Run deployment:
```bash
./deploy-prod.sh
```

## 5. SSL Certificate Setup

The deployment script handles SSL certificate generation automatically, but you can manually renew or check status:

```bash
# Check certificate status
certbot certificates

# Manual renewal
certbot renew --dry-run
```

## 6. Monitoring Setup

### A. Set up monitoring tools:

1. Install Prometheus and Grafana:
```bash
docker-compose -f docker-compose.monitoring.yml up -d
```

2. Access Grafana dashboard:
```
https://badbeatstools.io:3000
```

### B. Set up log monitoring:

1. Configure log rotation:
```bash
nano /etc/logrotate.d/badbeatstools
```

2. Set up log alerts:
```bash
docker-compose -f docker-compose.monitoring.yml up -d alertmanager
```

## 7. Backup Setup

### A. Configure automated backups:

1. Database backups:
```bash
# Add to crontab
0 0 * * * /path/to/backup-db.sh
```

2. File backups:
```bash
# Add to crontab
0 1 * * * /path/to/backup-files.sh
```

## 8. CDN Setup (Optional)

1. Configure Cloudflare:
   - Add your domain to Cloudflare
   - Update nameservers with your registrar
   - Enable HTTPS and HTTP/2
   - Configure caching rules

## 9. Post-Deployment Checks

1. Verify SSL setup:
```bash
curl -vI https://badbeatstools.io
```

2. Check application logs:
```bash
docker-compose -f docker-compose.prod.yml logs -f
```

3. Monitor resource usage:
```bash
docker stats
```

## 10. Maintenance

### A. Regular maintenance tasks:

1. Update SSL certificates:
```bash
# Automated via cron, but can be manually triggered
certbot renew
```

2. Update application:
```bash
./deploy-prod.sh
```

3. Monitor disk space:
```bash
df -h
```

### B. Backup verification:

1. Regularly test backup restoration:
```bash
./test-backup-restore.sh
```

## Troubleshooting

### Common Issues:

1. SSL Certificate Issues:
```bash
certbot certificates
certbot renew --dry-run
```

2. Database Connection Issues:
```bash
docker-compose -f docker-compose.prod.yml exec db pg_isready
```

3. Nginx Issues:
```bash
nginx -t
docker-compose -f docker-compose.prod.yml logs nginx
```

## Security Recommendations

1. Enable 2FA for all admin accounts
2. Regularly update all passwords
3. Monitor for suspicious activity
4. Keep all software updated
5. Regularly review access logs
6. Implement rate limiting
7. Use WAF (Web Application Firewall)

## Support

For support issues:
- Email: support@badbeatstools.io
- Documentation: https://docs.badbeatstools.io
- Status Page: https://status.badbeatstools.io

Remember to regularly check for updates and security patches!
