#!/bin/bash
set -e

# Enable CloudWatch agent and basic monitoring
yum update -y
yum install -y amazon-cloudwatch-agent

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install health check script dependencies
yum install -y curl wget

# Create log directory
mkdir -p /var/log/health-check

# Download and setup health check script
cat > /usr/local/bin/health-check.sh << 'EOF'
#!/bin/bash

LOG_DIR="/var/log/health-check"
LOG_FILE="$LOG_DIR/health-check.log"
DISK_THRESHOLD=80

[ -d "$LOG_DIR" ] || mkdir -p "$LOG_DIR"

{
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] === System Health Check ==="
    
    # Disk usage check
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] DISK: $DISK_USAGE% used ✗ CRITICAL"
        EXIT_CODE=1
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] DISK: $DISK_USAGE% used ✓"
        EXIT_CODE=0
    fi
    
    # Memory usage check
    MEM_USAGE=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] MEMORY: $MEM_USAGE% used ✓"
    
    # Docker service check
    if systemctl is-active --quiet docker; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] DOCKER: running ✓"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] DOCKER: not running ✗"
        EXIT_CODE=1
    fi
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Status: $([ $EXIT_CODE -eq 0 ] && echo 'OK' || echo 'CRITICAL')"
    echo "---"
    
} >> "$LOG_FILE"

exit $EXIT_CODE
EOF

chmod +x /usr/local/bin/health-check.sh

# Schedule health check every 5 minutes
echo "*/5 * * * * /usr/local/bin/health-check.sh" | crontab -

# Create nginx container
docker run -d --name web \
  -p 80:80 \
  -e DB_HOST="${db_host}" \
  -e DB_NAME="${db_name}" \
  -e DB_USER="${db_user}" \
  nginx:latest

echo "Setup complete" >> /var/log/health-check/health-check.log
