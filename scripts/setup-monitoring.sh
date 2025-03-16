#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Setting up BadbeatsTools monitoring system...${NC}"

# Create necessary directories
echo -e "${GREEN}Creating monitoring directories...${NC}"
mkdir -p monitoring/prometheus/rules
mkdir -p monitoring/grafana/data
mkdir -p monitoring/loki/data
mkdir -p monitoring/alertmanager/templates

# Make scripts executable
chmod +x scripts/*.sh

# Set up Prometheus recording rules
echo -e "${GREEN}Setting up Prometheus recording rules...${NC}"
cat > monitoring/prometheus/rules/recording_rules.yml << EOL
groups:
  - name: badbeatstools_recording_rules
    rules:
      - record: job:request_latency_seconds:mean5m
        expr: rate(flask_http_request_duration_seconds_sum[5m]) / rate(flask_http_request_duration_seconds_count[5m])
      - record: job:request_rate:5m
        expr: rate(flask_http_request_total[5m])
EOL

# Set up Prometheus alerting rules
echo -e "${GREEN}Setting up Prometheus alerting rules...${NC}"
cat > monitoring/prometheus/rules/alerting_rules.yml << EOL
groups:
  - name: badbeatstools_alerts
    rules:
      - alert: HighRequestLatency
        expr: job:request_latency_seconds:mean5m > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: High request latency on {{ \$labels.instance }}
          description: Request latency is above 1s (current value: {{ \$value }}s)

      - alert: HighErrorRate
        expr: rate(flask_http_request_total{status=~"5.."}[5m]) > 0.1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: High error rate on {{ \$labels.instance }}
          description: Error rate is above 10% (current value: {{ \$value }})

      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: High memory usage on {{ \$labels.instance }}
          description: Memory usage is above 90% (current value: {{ \$value }}%)

      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: High CPU usage on {{ \$labels.instance }}
          description: CPU usage is above 90% (current value: {{ \$value }}%)

      - alert: LowDiskSpace
        expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 < 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: Low disk space on {{ \$labels.instance }}
          description: Disk space is below 10% (current value: {{ \$value }}%)
EOL

# Set up AlertManager templates
echo -e "${GREEN}Setting up AlertManager templates...${NC}"
cat > monitoring/alertmanager/templates/default.tmpl << EOL
{{ define "slack.default.title" }}
[{{ .Status | toUpper }}{{ if eq .Status "firing" }}:{{ .Alerts.Firing | len }}{{ end }}] {{ .CommonLabels.alertname }}
{{ end }}

{{ define "slack.default.text" }}
{{ range .Alerts }}
*Alert:* {{ .Labels.alertname }}
*Description:* {{ .Annotations.description }}
*Severity:* {{ .Labels.severity }}
*Instance:* {{ .Labels.instance }}
*Values:* {{ .Annotations.value }}
{{ end }}
{{ end }}
EOL

# Start monitoring stack
echo -e "${GREEN}Starting monitoring stack...${NC}"
docker-compose -f docker-compose.monitoring.yml up -d

# Wait for services to be ready
echo -e "${YELLOW}Waiting for services to be ready...${NC}"
sleep 30

# Check if services are running
echo -e "${GREEN}Checking service status...${NC}"
if docker-compose -f docker-compose.monitoring.yml ps | grep -q "Up"; then
    echo -e "${GREEN}Monitoring setup completed successfully!${NC}"
    echo -e "\n${YELLOW}Access Points:${NC}"
    echo -e "- Grafana: ${GREEN}http://localhost:3000${NC}"
    echo -e "- Prometheus: ${GREEN}http://localhost:9090${NC}"
    echo -e "- AlertManager: ${GREEN}http://localhost:9093${NC}"
    
    echo -e "\n${YELLOW}Default Credentials:${NC}"
    echo -e "Grafana:"
    echo -e "- Username: ${GREEN}admin${NC}"
    echo -e "- Password: ${GREEN}admin${NC}"
    
    echo -e "\n${YELLOW}Next Steps:${NC}"
    echo -e "1. Change default passwords"
    echo -e "2. Configure alert notifications"
    echo -e "3. Review and adjust alerting rules"
    echo -e "4. Set up additional dashboards"
else
    echo -e "${RED}Monitoring setup failed. Please check the logs:${NC}"
    docker-compose -f docker-compose.monitoring.yml logs
fi

# Make the script executable
chmod +x scripts/setup-monitoring.sh
