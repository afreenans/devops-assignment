
# AWS Architecture Design Document

## Complete System Architecture

```
                              ┌─────────────────────────────────┐
                              │     INTERNET (0.0.0.0/0)        │
                              └────────────────┬────────────────┘
                                              │
                                    ┌─────────▼────────────┐
                                    │   Route 53 (DNS)     │
                                    └─────────┬────────────┘
                                              │
                              ┌───────────────▼──────────────┐
                              │      AWS Region: us-east-1   │
                              │   ┌────────────────────────┐  │
                              │   │ Internet Gateway (IGW) │  │
                              │   └────────┬───────────────┘  │
                              │            │                  │
                              │   ┌────────▼───────────────┐  │
                              │   │  VPC: 10.0.0.0/16      │  │
                              │   │                        │  │
                              │   │ ┌──────────────────┐   │  │
                              │   │ │  PUBLIC SUBNET   │   │  │
                              │   │ │  10.0.1.0/24     │   │  │
                              │   │ │                  │   │  │
                              │   │ │ ┌──────────────┐ │   │  │
                              │   │ │ │     ALB      │ │   │  │
                              │   │ │ │   (:80/443)  │ │   │  │
                              │   │ │ └────┬─────────┘ │   │  │
                              │   │ │      │           │   │  │
                              │   │ │ ┌────▼────────┐  │   │  │
                              │   │ │ │ Bastion     │  │   │  │
                              │   │ │ │ Host        │  │   │  │
                              │   │ │ │ (:22)       │  │   │  │
                              │   │ │ └────────────┘  │   │  │
                              │   │ └──────────────────┘   │  │
                              │   │                        │  │
                              │   │ ┌──────────────────┐   │  │
                              │   │ │  PRIVATE SUBNET  │   │  │
                              │   │ │  10.0.2.0/24     │   │  │
                              │   │ │                  │   │  │
                              │   │ │ ┌──────────────┐ │   │  │
                              │   │ │ │ EC2 Instance│ │   │  │
                              │   │ │ │  (App:80)   │ │   │  │
                              │   │ │ └──────────────┘ │   │  │
                              │   │ │                  │   │  │
                              │   │ │ ┌──────────────┐ │   │  │
                              │   │ │ │     NAT      │ │   │  │
                              │   │ │ │   Gateway    │ │   │  │
                              │   │ │ └──────────────┘ │   │  │
                              │   │ └──────────────────┘   │  │
                              │   │                        │  │
                              │   │ ┌──────────────────┐   │  │
                              │   │ │  RDS Database    │   │  │
                              │   │ │  PostgreSQL      │   │  │
                              │   │ │  (Port 5432)     │   │  │
                              │   │ │  (Encrypted)     │   │  │
                              │   │ └──────────────────┘   │  │
                              │   │                        │  │
                              │   └────────────────────────┘  │
                              └────────────────────────────────┘
```

## Network Design

### Public Subnet (10.0.1.0/24)
- **Resources**: ALB, Bastion Host, NAT Gateway
- **Internet Access**: ✓ Yes (via IGW)
- **Route**: 0.0.0.0/0 → IGW

### Private Subnet (10.0.2.0/24)
- **Resources**: EC2 App Server, RDS Database
- **Internet Access**: ✓ Yes (outbound only via NAT)
- **Route**: 0.0.0.0/0 → NAT Gateway

## Data Flow

### User Request Flow

```
User → Route 53 → ALB (Port 80/443) → EC2 (Port 80) → RDS (Port 5432)
```

### Administrative Access

```
Admin SSH → Bastion (Public) → EC2 (Private)
```

## Security Boundaries

```
Layer 1: VPC Firewall (NACLs)
         ↓
Layer 2: Public SG (ALB)
         ├─ Inbound: 80, 443 from 0.0.0.0/0
         ├─ Outbound: All to EC2-SG
         
Layer 3: Application SG (EC2)
         ├─ Inbound: 80, 443 from ALB-SG
         ├─ Inbound: 22 from Bastion-SG
         ├─ Outbound: All
         
Layer 4: Database SG (RDS)
         ├─ Inbound: 5432 from EC2-SG only
         └─ Outbound: None
```

## Key Design Decisions

### 1. Single AZ Deployment
**Rationale**: Cost optimization for development/testing
**Trade-off**: Lower availability (no HA)
**Production Upgrade**: Multi-AZ RDS + Auto Scaling Group

### 2. Private Database
**Rationale**: Reduces attack surface
**Benefit**: No direct internet exposure
**Access**: Only through EC2 application layer

### 3. Bastion Host
**Rationale**: Single entry point for SSH
**Alternative**: AWS Systems Manager Session Manager (no bastion needed)
**Benefit**: Audit trail and access control

### 4. Encryption
**Rationale**: Security best practice
**Encryption At Rest**: RDS with KMS
**Encryption In Transit**: SSL/TLS connections
**Keys**: AWS-managed or customer-managed

## Cost Analysis

### Instance Types (Cost-Conscious)

| Resource | Type | Size | Monthly Cost |
|----------|------|------|-------------|
| Compute | t3.micro | 1 vCPU, 1GB RAM | $7.50 |
| Database | db.t3.micro | 1 vCPU, 1GB RAM | $30.00 |
| Load Balancer | ALB | - | $16.20 |
| NAT Gateway | - | - | $32.00 |
| **Total** | - | - | **$85.70** |

### Optimization Techniques

1. **Burstable Instances**: t3 family (good for variable workloads)
2. **Single AZ**: Eliminates cross-AZ data transfer costs
3. **gp3 Storage**: 20% cheaper than gp2
4. **Minimal Backups**: 7-day retention (not unlimited)
5. **VPC Endpoints**: For S3 access (eliminates NAT costs)

## Monitoring Strategy

### Metrics Collected

**EC2 Instance:**
- CPU Utilization
- Memory Usage
- Disk Utilization
- Network I/O
- Status Checks

**RDS Database:**
- CPU Utilization
- Database Connections
- Storage Space
- Read/Write Latency
- IOPS

**Application Load Balancer:**
- Request Count
- Response Codes (2xx, 4xx, 5xx)
- Target Health Status
- Response Time

### Alerting Thresholds

```
CPU > 80% for 5 min         → Warning
Memory > 85%                → Warning
Disk > 80%                  → Critical (exit code 1)
DB Connections > 80%        → Warning
ALB Unhealthy Targets > 0   → Critical
```

## High Availability (Future)

### Current State (Development)
- Single EC2 instance
- Single AZ RDS
- No auto-scaling
- RTO: ~15 minutes, RPO: ~5 minutes

### Production Upgrade Path

```hcl
# Multi-AZ RDS
multi_az = true

# Auto Scaling Group (instead of single EC2)
min_size = 2
max_size = 4
availability_zones = ["us-east-1a", "us-east-1b"]

# Cross-AZ Load Balancer
enable_cross_zone = true
```

### Benefits
- **RTO**: < 5 minutes (automatic failover)
- **RPO**: Near-zero (synchronous replication)
- **Availability**: 99.95% SLA

## Disaster Recovery

### Backup Strategy

```
RDS Automated Backups:
  ├─ Retention: 7 days
  ├─ Frequency: Daily
  ├─ Type: Full + Incremental
  └─ Point-in-Time Recovery: ✓

Application State:
  ├─ Stateless (easier recovery)
  ├─ New instance: < 5 minutes
  └─ AMI-based recovery: ✓
```

### Recovery Procedures

1. **Database Failure**: Restore from RDS snapshot
2. **Application Failure**: Re-launch EC2 from AMI
3. **Complete Region Failure**: Failover to secondary region (future)

## Security Best Practices

✓ Network Segmentation (public/private)
✓ Encryption at rest (RDS/EBS)
✓ Encryption in transit (SSL)
✓ IAM role-based access
✓ Security group least privilege
✓ No hardcoded credentials
✓ Automated backups enabled
✓ CloudWatch logging enabled
✓ Health checks automated

## Scaling Considerations

### Vertical Scaling (Larger Instances)
```hcl
instance_type = "t3.small"    # from t3.micro
db_instance_class = "db.t3.small"
```

### Horizontal Scaling (More Instances)
```hcl
# Auto Scaling Group
desired_capacity = 3
min_size = 2
max_size = 6
```

### Database Scaling
```hcl
# Read Replicas
create_read_replica = true

# Or upgrade to Aurora
engine = "aurora-postgresql"
```

