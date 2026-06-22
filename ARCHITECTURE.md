# Architecture Design Document

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         INTERNET / USERS                            │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                         ┌───────▼────────┐
                         │   Route 53     │
                         │   (DNS)        │
                         └───────┬────────┘
                                 │
                    ┌────────────▼────────────┐
                    │      AWS Region        │
                    │    (e.g., us-east-1)   │
                    │                        │
                    │  ┌──────────────────┐  │
                    │  │     Internet     │  │
                    │  │     Gateway      │  │
                    │  │    (IGW)         │  │
                    │  └────────┬─────────┘  │
                    │           │            │
                    │  ┌────────▼──────────┐ │
                    │  │ VPC: 10.0.0.0/16 │ │
                    │  │                  │ │
        ┌───────────┤  │ ┌──────────────┐ │ │
        │           │  │ │Public Subnet │ │ │
        │ Security  │  │ │10.0.1.0/24   │ │ │
        │ Group:    │  │ │              │ │ │
        │ HTTP/HTTPS│  │ │  ┌─────────┐ │ │ │
        │ 80,443    │  │ │  │   ALB   │ │ │ │
        │           │  │ │  │(Port 80)│ │ │ │
        │           │  │ │  └────┬────┘ │ │ │
        └─────┬─────┤  │ │       │      │ │ │
              │     │  │ │  ┌────▼────┐ │ │ │
              │     │  │ │  │ Bastion │ │ │ │
              │     │  │ │  │ Host    │ │ │ │
              │     │  │ │  │(SSH:22) │ │ │ │
              │     │  │ │  └─────────┘ │ │ │
              │     │  │ └──────────────┘ │ │
              │     │  │                  │ │
              │     │  │ ┌──────────────┐ │ │
              │     │  │ │Private Subnet│ │ │
              │     │  │ │10.0.2.0/24   │ │ │
              │     │  │ │              │ │ │
              │     │  │ │ ┌──────────┐ │ │ │
              │     │  │ │ │  EC2     │ │ │ │
              │     │  │ │ │ Instance │ │ │ │
              │     │  │ │ │(App:80)  │ │ │ │
              │     │  │ │ └────┬─────┘ │ │ │
              │     │  │ │      │       │ │ │
              │     │  │ │  ┌───▼────┐  │ │ │
              │     │  │ │  │ NAT    │  │ │ │
              │     │  │ │  │Gateway │  │ │ │
              │     │  │ │  └────────┘  │ │ │
              │     │  │ └──────────────┘ │ │
              │     │  │                  │ │
              │     │  │ ┌──────────────┐ │ │
              │     │  │ │DB Subnet Grp │ │ │
              │     │  │ │              │ │ │
              │     │  │ │ ┌──────────┐ │ │ │
              │     │  │ │ │RDS       │ │ │ │
              │     │  │ │ │PostgreSQL│ │ │ │
              │     │  │ │ │Port:5432 │ │ │ │
              │     │  │ │ │(Encrypted)│ │ │ │
              │     │  │ │ └──────────┘ │ │ │
              │     │  │ └──────────────┘ │ │
              │     │  │                  │ │
              │     │  │  CloudWatch      │ │
              │     │  │  Logs & Metrics  │ │
              │     │  └──────────────────┘ │
              │     └──────────────────────┘ │
              └────────────────────────────────┘

Legend:
  ━━━ = Public connectivity
  ┃   = Private connectivity (private subnets)
  [ ] = AWS Resources
```

## Data Flow

### 1. User Request Flow

```
User Request
    ↓
Route 53 (DNS Resolution) 
    ↓
ALB DNS Name (e.g., app-alb-123456.us-east-1.elb.amazonaws.com)
    ↓
ALB in Public Subnet (Port 80/443)
    ↓
Security Group Check: Allow 0.0.0.0/0:80,443
    ↓
Target Group Health Check
    ↓
EC2 Instance in Private Subnet (Port 80)
    ↓
Security Group Check: Allow ALB-SG:80
    ↓
Application Layer (Container/Service)
    ↓
Database Query
    ↓
RDS PostgreSQL in Private Subnet (Port 5432)
    ↓
Security Group Check: Allow EC2-SG:5432
    ↓
Response Back to User
```

### 2. Administrative Access Flow (via Bastion)

```
Admin SSH Request
    ↓
Bastion Host in Public Subnet (Port 22)
    ↓
Security Group: Allow <ADMIN-IP>:22
    ↓
SSH to EC2 Private Instance
    ↓
SSH from within Bastion to EC2 (Private IP)
    ↓
Interactive Terminal
```

### 3. Alternative: SSM Session Manager Flow

```
AWS Console / AWS CLI
    ↓
IAM User with ssm:StartSession permission
    ↓
Systems Manager Session Manager
    ↓
EC2 Instance IAM Role grants permission
    ↓
Secure Shell Session (encrypted via KMS)
    ↓
No SSH key needed, Full audit trail
```

## Network Segmentation

### Public Subnet (10.0.1.0/24)
- **Resources:** ALB, Bastion Host, NAT Gateway
- **Internet Access:** ✓ (via Internet Gateway)
- **Inbound:** HTTP/HTTPS, SSH (bastion only)
- **Outbound:** All

### Private Subnet (10.0.2.0/24)
- **Resources:** EC2 App Servers, RDS Database
- **Internet Access:** ✓ (via NAT Gateway for outbound only)
- **Inbound:** Only from ALB/Bastion
- **Outbound:** All (via NAT)

### Database Tier
- **Resources:** RDS in private subnet(s)
- **Network Access:** EC2 instances only via Security Groups
- **Backup:** Automated snapshots
- **Encryption:** KMS encryption at rest

## Security Boundaries

```
┌─────────────────────────────────────────┐
│         INTERNET (Untrusted)            │
└──────────────┬──────────────────────────┘
               │
        ┌──────▼─────────────────┐
        │  VPC Security Boundary │  (Firewall)
        │  ├─ VPC Flow Logs      │
        │  └─ NACLs              │
        └──────┬─────────────────┘
               │
        ┌──────▼──────────────────────┐
        │  PUBLIC SUBNET (DMZ)        │
        │  ├─ ALB                     │
        │  ├─ Bastion Host            │
        │  └─ Nat Gateway             │
        │  SG: HTTP/HTTPS/SSH         │
        └──────┬──────────────────────┘
               │
        ┌──────▼──────────────────────┐
        │  APPLICATION SECURITY       │
        │  Group (EC2 Instances)      │
        │  ├─ Allow ALB:80,443        │
        │  ├─ Allow Bastion:22        │
        │  └─ Deny from Internet      │
        └──────┬──────────────────────┘
               │
        ┌──────▼──────────────────────┐
        │  DATABASE SECURITY GROUP    │
        │  (RDS PostgreSQL)           │
        │  ├─ Allow EC2:5432 only     │
        │  ├─ Encryption enabled      │
        │  └─ No external access      │
        └─────────────────────────────┘
```

## High Availability Considerations

### Current Implementation (Single AZ)
- **Cost:** Optimized
- **Downtime Risk:** High (single point of failure)
- **RPO:** ~5 minutes (automated backups)
- **RTO:** ~15 minutes (snapshot restore)

### Production Upgrade Path (Multi-AZ)

```hcl
# RDS Multi-AZ (recommended for HA)
multi_az = true  # Synchronous replication to standby

# EC2 Auto Scaling Group (instead of single instance)
min_size = 2
max_size = 4
availability_zones = ["us-east-1a", "us-east-1b"]

# ALB automatically distributes across AZs
```

## Monitoring & Observability

### Metrics Collected

#### EC2 Instance
```
- CPU Utilization (%)
- Memory Utilization (via CloudWatch agent)
- Disk Utilization (via health check script)
- Network In/Out (bytes)
- Status Checks (system & instance)
```

#### RDS Instance
```
- CPU Utilization (%)
- Database Connections
- Storage Space (bytes)
- Read/Write Latency (ms)
- IOPS
- Failover events (Multi-AZ)
```

#### Application Load Balancer
```
- Request Count
- HTTP 2xx/4xx/5xx Response Count
- Target Health Status
- Response Time (ms)
- Active Connections
```

### Alarms (Recommended)

```hcl
# CPU spike on EC2
cpu_utilization > 80% for 5 minutes

# Database connection limit
database_connections > 80 for 10 minutes

# ALB target health
unhealthy_host_count > 0 for 2 minutes

# RDS storage threshold
free_storage_space < 5GB

# Disk usage from health check script
disk_utilization > 80%
```

## Disaster Recovery

### Backup Strategy

```
RDS Automated Backups:
  - Retention: 7 days
  - Frequency: Daily
  - Point-in-time recovery: 7 days

Manual Snapshots:
  - Weekly snapshots
  - Cross-region replication (future)
```

### Recovery Procedures

1. **Database Failure:**
   - Restore from RDS snapshot (15-30 min)
   - Update connection strings
   - Verify data integrity

2. **Application Server Failure:**
   - Replace EC2 instance using AMI
   - Re-attach security groups
   - Update load balancer targets

3. **Multi-Region (Future):**
   - Route 53 health checks
   - Auto-failover to secondary region
   - Cross-region RDS replica

---

## Security Best Practices Implemented

✓ **Encryption in Transit & at Rest**
- RDS encrypted with AWS KMS
- SSL connections enforced
- HTTPS-ready (with certificate)

✓ **Network Isolation**
- Private subnets for databases
- Security groups for least privilege
- No direct internet access for backends

✓ **Access Control**
- IAM roles (not hardcoded credentials)
- Bastion host for administrative access
- Audit logging in CloudWatch

✓ **Monitoring & Compliance**
- CloudWatch logs for all services
- Health checks every 5 minutes
- Automated alerting

---

## Cost Analysis

### Monthly Cost Breakdown

| Component | Instance Type | Cost |
|-----------|---------------|------|
| EC2 | t3.micro (1 vCPU, 1GB) | $7.50 |
| RDS | db.t3.micro (1 vCPU, 1GB) | $30.00 |
| ALB | Application Load Balancer | $16.20 |
| NAT Gateway | Data processing | $32.00 |
| Data Transfer | Estimated outbound | $5.00 |
| **TOTAL** | | **~$90.70** |

### Cost Optimization Levers

1. **Compute:** Use Spot Instances (70% savings) for non-critical workloads
2. **RDS:** Reserved Instances (40% savings) for 1-3 year commitment
3. **Data Transfer:** Use VPC endpoints for S3 (eliminate NAT costs)
4. **Storage:** gp3 instead of gp2 (20% cheaper)

---
```
