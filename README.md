

## Project Overview

This submission demonstrates a secure, production-aware AWS architecture for a containerized web application with complete infrastructure-as-code implementation.

---

## Table of Contents

1. [Architecture Design](#architecture-design)
2. [Setup Instructions](#setup-instructions)
3. [Terraform Implementation](#terraform-implementation)
4. [Scripts & Monitoring](#scripts--monitoring)
5. [Assumptions & Design Decisions](#assumptions--design-decisions)
6. [Security Considerations](#security-considerations)
7. [Cost Optimization](#cost-optimization)
8. [Troubleshooting](#troubleshooting)

---

## Architecture Design

### Overview

The architecture implements a secure, scalable infrastructure following AWS Well-Architected Framework principles:

- **VPC with Public/Private Subnets** - Network isolation and security
- **ALB (Application Load Balancer)** - Public entry point for containerized apps
- **ECS/EC2 Cluster** - Container orchestration in private subnet
- **RDS PostgreSQL** - Database in private subnet with encryption
- **Bastion Host** - Secure administrative access (optional SSM alternative)
- **Security Groups** - Least privilege network access
- **CloudWatch** - Comprehensive monitoring and logging

### Key Architecture Principles

```
Internet (Users)
    ↓
Route 53 (DNS)
    ↓
Application Load Balancer (Public Subnet)
    ↓
Security Group (ALB) - Allow 80/443
    ↓
EC2 Instances / ECS Tasks (Private Subnet)
    ↓
RDS PostgreSQL (Private Subnet, Encrypted)
```

---

## Setup Instructions

### Prerequisites

```bash
# Install required tools
- Terraform >= 1.0
- AWS CLI v2
- jq (for JSON parsing)
- Git

# Verify installations
terraform version
aws --version
```

### AWS Setup

```bash
# 1. Configure AWS Credentials
aws configure
# Enter:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region (e.g., us-east-1)
# - Default output format (json)

# 2. Verify AWS access
aws sts get-caller-identity
```

### Deployment Steps

```bash
# 1. Clone/extract repository
git clone <your-repo-url> devops-assignment
cd devops-assignment/terraform

# 2. Initialize Terraform
terraform init

# 3. Create terraform.tfvars from example
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values:
nano terraform.tfvars

# 4. Validate configuration
terraform validate

# 5. Plan deployment
terraform plan -out=tfplan

# 6. Apply configuration
terraform apply tfplan

# 7. Capture outputs
terraform output -json > outputs.json
```

### Post-Deployment

```bash
# Get ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns_name)
echo "Application available at: http://$ALB_DNS"

# Get Bastion host IP (if deployed)
BASTION_IP=$(terraform output -raw bastion_public_ip)
echo "Bastion Host: $BASTION_IP"

# Connect to RDS (through Bastion or SSM)
# Connection string will be in outputs
```

### Cleanup

```bash
# Destroy all resources (caution: irreversible)
terraform destroy

# Or target specific resources
terraform destroy -target=aws_instance.app_server
```

---

## Terraform Implementation

### Project Structure

```
terraform/
├── main.tf           # VPC, subnets, routing
├── security.tf       # Security groups, IAM roles
├── variables.tf      # Input variables with validation
├── outputs.tf        # Exported outputs for post-deployment
└── terraform.tfvars.example  # Example values
```

### Variable Configuration

All sensitive values use variables to prevent hardcoding:

```hcl
# Database password (never hardcoded)
variable "db_password" {
  type        = string
  sensitive   = true
  description = "RDS master password"
}

# Use with: -var="db_password=YourPassword123!"
# Or store in terraform.tfvars (add to .gitignore)
# Or use AWS Secrets Manager
```

### Key Components

#### 1. VPC & Networking
- VPC CIDR: 10.0.0.0/16
- Public Subnet: 10.0.1.0/24 (AZ: a)
- Private Subnet: 10.0.2.0/24 (AZ: a)
- NAT Gateway for private subnet outbound access
- Internet Gateway for public subnet

#### 2. Security Groups

```
ALB Security Group:
  - Inbound: 80, 443 from 0.0.0.0/0
  - Outbound: All to EC2 security group

EC2 Security Group:
  - Inbound: 80, 443 from ALB SG
  - Inbound: 22 from Bastion SG (or SSM)
  - Outbound: All (for package updates)

RDS Security Group:
  - Inbound: 5432 from EC2 SG only
  - Outbound: None needed

Bastion Security Group:
  - Inbound: 22 from your IP (CIDR variable)
  - Outbound: All
```

#### 3. IAM Roles

**EC2 Instance Role:**
```
Permissions:
  - ECR read access (pulling images)
  - CloudWatch logs write
  - SSM Session Manager (for secure access)
  - S3 read access (for artifacts/configs)
```

**RDS:**
- IAM database authentication enabled
- Encrypted with KMS

---

## Scripts & Monitoring

### Health Check Script

Located in: `scripts/health-check.sh`

**Features:**
- Disk usage monitoring (alert > 80%)
- Memory usage tracking
- Docker service status verification
- Timestamped logging
- Non-zero exit code on critical issues

**Usage:**

```bash
# Make executable
chmod +x scripts/health-check.sh

# Run once
./scripts/health-check.sh

# Schedule with cron (every 5 minutes)
*/5 * * * * /path/to/health-check.sh

# View logs
tail -f /var/log/health-check/health-check.log
```

**Log Output Example:**
```
[2024-01-15 10:30:45] === System Health Check ===
[2024-01-15 10:30:45] DISK: 65% used ✓
[2024-01-15 10:30:45] MEMORY: 72% used ✓
[2024-01-15 10:30:45] DOCKER: running ✓
[2024-01-15 10:30:45] Status: OK
```

---

## Assumptions & Design Decisions

### Assumptions Made

| Assumption | Rationale | Alternative |
|-----------|-----------|-------------|
| Single AZ deployment | Cost optimization for dev/test | Multi-AZ for HA (higher cost) |
| PostgreSQL RDS | Industry standard for web apps | Aurora for auto-scaling |
| t3.micro instances | Cost-conscious (free tier eligible) | t3.small/medium for higher load |
| Bastion host for access | Simple, traditional approach | SSM Session Manager (no bastion) |
| CloudWatch monitoring | Integrated with AWS | Prometheus + Grafana stack |
| No multi-region | Scope constraints | DynamoDB + Route 53 for DR |

### Design Decisions

#### 1. **Networking Design**

**Decision:** Single VPC with public/private subnets
**Why:** 
- Clear separation of concerns
- Security boundaries (private resources not directly accessible)
- NAT Gateway provides outbound internet access for updates

**Alternative Rejected:** 
- Multiple VPCs would add complexity without value for single app

#### 2. **Database Placement**

**Decision:** RDS in private subnet only
**Why:**
- No direct internet access = reduced attack surface
- Only accessible from application layer
- Encrypted at rest and in transit
- Automated backups enabled

**Alternative Rejected:**
- Public RDS is a security anti-pattern

#### 3. **Access Control**

**Decision:** Bastion host in public subnet for SSH
**Why:**
- Single entry point for administrative access
- Audit trail via CloudWatch Logs
- Low cost (t2.micro)

**Better Alternative:** SSM Session Manager
- No bastion host needed
- Uses IAM for authentication
- No key management
- Can be implemented by changing user_data scripts

#### 4. **Secrets Management**

**Decision:** RDS password via Terraform variables
**Why:**
- Acceptable for demo/test environments
- Variable marked as sensitive

**Production Alternative:**
```hcl
# Use AWS Secrets Manager
resource "aws_secretsmanager_secret" "rds_password" {
  name = "rds/master-password"
}

# Reference in RDS
master_user_password = aws_secretsmanager_secret.rds_password.id
```

#### 5. **Monitoring Strategy**

**Decision:** CloudWatch native monitoring
**Why:**
- Zero configuration with AWS integration
- Automatic metrics (CPU, disk, memory)
- Log aggregation for application logs
- Cost-effective alerting

**Metrics Monitored:**
```
EC2:
  - CPU Utilization
  - Network I/O
  - Status Checks

RDS:
  - CPU Utilization
  - Database Connections
  - Storage Space
  - Read/Write Latency

ALB:
  - Request Count
  - Target Health
  - Response Time
```

#### 6. **Cost Optimization**

**Strategies Implemented:**

1. **Compute**: t3.micro instances (1 vCPU, 1GB RAM)
2. **Storage**: gp3 for RDS (cost-effective, good performance)
3. **Data Transfer**: Private subnets reduce NAT costs
4. **Backups**: 7-day retention for RDS (minimal storage)
5. **Monitoring**: CloudWatch free tier usage

**Monthly Cost Estimate (us-east-1):**
```
EC2 (t3.micro, on-demand)        $7.50
RDS (db.t3.micro, PostgreSQL)    $30.00
ALB (hourly + requests)           $16.20
NAT Gateway                       $32.00
Data Transfer (estimated)         $5.00
                                  ------
Approximate Total:                $90.70/month
```

---

## Security Considerations

### Network Security

```hcl
# 1. Security Group Strategy (Principle of Least Privilege)

# ALB - Public facing
allow 0.0.0.0/0 -> 80, 443

# EC2 - Private, app layer
allow ALB-SG -> 80, 443
allow Bastion-SG -> 22
deny all else

# RDS - Database layer
allow EC2-SG -> 5432
deny all else
```

### Data Security

```hcl
# 1. Encryption at Rest
- RDS encrypted with KMS
- EBS volumes encrypted
- S3 buckets (if used) with encryption

# 2. Encryption in Transit
- ALB -> EC2: HTTP (can enable HTTPS with cert)
- EC2 -> RDS: SSL enabled
- VPC endpoint for S3 (if used)
```

### Access Control

```hcl
# 1. IAM Roles (no credentials on instances)
- EC2 Instance role for ECR access
- Separate roles for each function

# 2. Network Access Control
- Security groups (stateful firewall)
- NACLs (stateless firewall) for explicit deny

# 3. Bastion Host Hardening
- Minimal AMI (Amazon Linux 2)
- Security updates enabled
- CloudWatch agent for monitoring
- Key-based authentication only
```

### Compliance

```
✓ Data encryption (rest & transit)
✓ Network isolation (public/private)
✓ Access logging (CloudWatch)
✓ IAM role-based access
✓ Automated backups
✗ Multi-region (future enhancement)
✗ Compliance certifications (depends on workload)
```

---

## Cost Optimization

### Implementation Strategies

| Item | Optimization | Savings |
|------|--------------|---------|
| Compute | t3.micro (burstable) | ~70% vs m5.large |
| Storage | gp3 over gp2 | 20% cheaper |
| RDS | Single AZ | 50% vs Multi-AZ |
| Backups | 7-day retention | vs unlimited |
| Data Transfer | Private subnets | Avoid NAT for internal traffic |

### Budget Controls

```bash
# Set up AWS Budget alerts
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account) \
  --budget file://budget.json \
  --notifications-with-subscribers \
    file://notifications.json
```

### Cost Monitoring

```bash
# Check daily costs
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost
```

### Scaling Up Safely

When moving to production:
```hcl
# Change instance types
variable "instance_type" {
  default = "t3.small"  # instead of micro
}

# Enable Multi-AZ for RDS
multi_az = true  # ~$30 additional

# Enable ALB cross-zone
enable_cross_zone_load_balancing = true
```

---

## Troubleshooting

### Common Issues & Solutions

#### 1. Terraform Apply Fails with Permission Denied

```bash
# Cause: AWS credentials not configured
# Solution:
aws configure
aws sts get-caller-identity  # Verify

# Or use environment variables:
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="us-east-1"
```

#### 2. EC2 Instance Can't Reach RDS

```bash
# Cause: Security group rules incorrect
# Debugging:
# 1. Check security groups in AWS console
# 2. Verify RDS is in same VPC
# 3. Test connectivity from EC2:

# Connect to EC2 via Bastion first:
ssh -i bastion.pem ec2-user@<bastion-ip>

# From EC2, test RDS:
curl telnet://<rds-endpoint>:5432

# Or use psql (if installed):
psql -h <rds-endpoint> -U admin -d postgres
```

#### 3. Bastion Host Unreachable

```bash
# Cause: Security group allows wrong IP
# Solution:
# Update Terraform variable:
variable "bastion_allowed_cidr" {
  default = "YOUR.IP.ADDRESS/32"  # Check with: curl ifconfig.me
}

# Reapply:
terraform apply -target=aws_security_group.bastion
```

#### 4. RDS Creation Times Out

```bash
# Cause: DB subnet group not configured correctly
# Solution:
# Ensure private subnets span multiple AZs for subnet group

# Or check:
aws rds describe-db-instances --db-instance-identifier app-db
```

#### 5. Health Check Script Errors

```bash
# Ensure proper permissions:
chmod +x scripts/health-check.sh

# Test directly:
bash -x scripts/health-check.sh

# Check log directory:
sudo mkdir -p /var/log/health-check
sudo chmod 755 /var/log/health-check
```

### Debugging Commands

```bash
# View Terraform state
terraform show

# Check specific resource
terraform state show aws_instance.app_server

# View CloudWatch logs
aws logs tail /aws/ec2/my-app --follow

# Test ALB connectivity
curl -I http://<alb-dns-name>

# Get EC2 instance details
aws ec2 describe-instances --filters "Name=tag:Name,Values=app-server"

# Check RDS status
aws rds describe-db-instances --db-instance-identifier app-db
```

---

## Additional Resources

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Security Best Practices](https://docs.aws.amazon.com/security/)
- [Container Security](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/container_agent_setup.html)

---

## Support & Questions

For issues or questions:
1. Check Troubleshooting section above
2. Review AWS documentation
3. Check Terraform logs: `TF_LOG=DEBUG terraform apply`
4. AWS Support (if you have an account)

---




