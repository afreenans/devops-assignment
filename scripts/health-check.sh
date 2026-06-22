#!/bin/bash

################################################################################
# System Health Check Script
# Purpose: Monitor disk, memory, Docker service and log results
# Exit Code: 0 = OK, 1 = CRITICAL (disk > 80%)
################################################################################

set -o pipefail

# Configuration
LOG_DIR="/var/log/health-check"
LOG_FILE="$LOG_DIR/health-check.log"
DISK_THRESHOLD=80
MEMORY_WARNING_THRESHOLD=85

# Color codes (for terminal output)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Initialize exit code
EXIT_CODE=0

# ============================================================================
# Helper Functions
# ============================================================================

# Create log directory if it doesn't exist
ensure_log_directory() {
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR" || {
            echo "ERROR: Cannot create log directory: $LOG_DIR" >&2
            exit 1
        }
    fi
}

# Log message to file and optionally to stdout
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log to file
    echo "[$timestamp] $level: $message" >> "$LOG_FILE"
    
    # Also output to stdout with color coding
    case "$level" in
        "ERROR")
            echo -e "${RED}[$timestamp] $level: $message${NC}"
            ;;
        "WARN")
            echo -e "${YELLOW}[$timestamp] $level: $message${NC}"
            ;;
        "INFO")
            echo -e "${GREEN}[$timestamp] $level: $message${NC}"
            ;;
        *)
            echo "[$timestamp] $level: $message"
            ;;
    esac
}

# ============================================================================
# System Checks
# ============================================================================

check_disk_usage() {
    log_message "INFO" "=== Disk Usage Check ==="
    
    # Get disk usage for root filesystem
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    DISK_AVAILABLE=$(df -h / | awk 'NR==2 {print $4}')
    DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
    
    log_message "INFO" "Disk Usage: $DISK_USED/$DISK_USED (${DISK_USAGE}% used, $DISK_AVAILABLE available)"
    
    if [ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ]; then
        log_message "ERROR" "Disk usage critical: ${DISK_USAGE}% exceeds threshold of ${DISK_THRESHOLD}%"
        EXIT_CODE=1
        return 1
    else
        log_message "INFO" "Disk usage normal: ${DISK_USAGE}%"
        return 0
    fi
}

check_memory_usage() {
    log_message "INFO" "=== Memory Usage Check ==="
    
    # Parse /proc/meminfo for more accurate memory metrics
    TOTAL_MEM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    AVAILABLE_MEM=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    USED_MEM=$((TOTAL_MEM - AVAILABLE_MEM))
    MEM_USAGE=$(( (USED_MEM * 100) / TOTAL_MEM ))
    
    # Convert to human readable format
    TOTAL_MEM_GB=$(awk "BEGIN {printf \"%.2f\", $TOTAL_MEM/1024/1024}")
    USED_MEM_GB=$(awk "BEGIN {printf \"%.2f\", $USED_MEM/1024/1024}")
    AVAILABLE_MEM_GB=$(awk "BEGIN {printf \"%.2f\", $AVAILABLE_MEM/1024/1024}")
    
    log_message "INFO" "Memory Usage: ${USED_MEM_GB}GB/${TOTAL_MEM_GB}GB ($MEM_USAGE% used, ${AVAILABLE_MEM_GB}GB available)"
    
    if [ "$MEM_USAGE" -gt "$MEMORY_WARNING_THRESHOLD" ]; then
        log_message "WARN" "Memory usage warning: ${MEM_USAGE}% exceeds warning threshold"
        return 1
    else
        log_message "INFO" "Memory usage normal: ${MEM_USAGE}%"
        return 0
    fi
}

check_docker_service() {
    log_message "INFO" "=== Docker Service Check ==="
    
    if ! command -v docker &> /dev/null; then
        log_message "WARN" "Docker is not installed"
        return 1
    fi
    
    if systemctl is-active --quiet docker; then
        DOCKER_STATUS="running"
        log_message "INFO" "Docker service is $DOCKER_STATUS"
        return 0
    else
        log_message "ERROR" "Docker service is not running"
        EXIT_CODE=1
        return 1
    fi
}

check_docker_containers() {
    log_message "INFO" "=== Docker Containers Check ==="
    
    if ! command -v docker &> /dev/null; then
        log_message "WARN" "Docker is not installed, skipping container check"
        return 0
    fi
    
    # Count running and stopped containers
    RUNNING=$(docker ps --quiet | wc -l) || RUNNING=0
    STOPPED=$(docker ps --quiet -a | wc -l) || STOPPED=0
    STOPPED=$((STOPPED - RUNNING))
    
    log_message "INFO" "Docker containers: $RUNNING running, $STOPPED stopped"
    return 0
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    ensure_log_directory
    
    # Print header
    {
        echo ""
        echo "=========================================="
        echo "System Health Check Report"
        echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Hostname: $(hostname)"
        echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
        echo "=========================================="
    } >> "$LOG_FILE"
    
    # Run all checks
    check_disk_usage
    check_memory_usage
    check_docker_service
    check_docker_containers
    
    # Summary
    {
        echo ""
        if [ $EXIT_CODE -eq 0 ]; then
            echo "Overall Status: ✓ HEALTHY"
        else
            echo "Overall Status: ✗ CRITICAL"
        fi
        echo "=========================================="
        echo ""
    } >> "$LOG_FILE"
    
    return $EXIT_CODE
}

# Execute main function
main
exit $?
