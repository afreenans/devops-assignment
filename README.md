
# DevOps Engineer – Technical Assessment Submission

## Project Overview

This submission demonstrates a secure, production-aware AWS architecture for a containerized web application with complete infrastructure-as-code implementation.

**Completion Time:** ~2.5 hours
**Status:** Complete

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
```

### AWS Setup

```bash
# 1. Configure AWS Credentials
aws configure

# 2. Verify AWS access
aws sts get-caller-identity
```

### Deployment Steps

```bash
# 1. Navigate to terraform directory
cd terraform

# 2. Initialize Terraform
terraform init

# 3. Create terraform.tfvars from example
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars

# 4. Validate configuration
terraform validate

# 5. Plan deployment
terraform plan -out=tfplan

# 6. Apply configuration
terraform apply tfplan
```

### Post-Deployment

```bash
# Get ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns_name)
echo "Application available at: http://$ALB_DNS"

# Get Bastion host IP
BASTION_IP=$(terraform output -raw bastion_public_ip)
echo "Bastion Host: $BASTION_IP"
```

### Cleanup

```bash
terraform destroy
```

---

## Terraform Implementation

### Project Structure

```
terraform/
├── main.tf           # VPC, subnets, routing, ALB, EC2, RDS
├── security.tf       # Security groups, IAM roles
├── variables.tf      # Input variables with validation
├── outputs.tf        # Exported outputs
└── terraform.tfvars.example  # Example configuration
```

### Key Features

1. **Network Isolation**: Public and private subnets
2. **Security**: Security groups with least privilege
3. **Database**: RDS PostgreSQL with encryption
4. **Load Balancing**: ALB for traffic distribution
5. **Monitoring**: CloudWatch integration
6. **IAM**: Role-based access control

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
chmod +x scripts/health-check.sh
./scripts/health-check.sh

# Schedule with cron (every 5 minutes)
*/5 * * * * /path/to/health-check.sh
```

---

## Assumptions & Design Decisions

### Key Assumptions

| Assumption | Rationale |
|-----------|-----------|
| Single AZ deployment | Cost optimization for dev/test |
| PostgreSQL RDS | Industry standard for web apps |
| t3.micro instances | Cost-conscious (free tier eligible) |
| Bastion host | Simple, traditional approach |

### Design Decisions

1. **Networking**: Single VPC with public/private subnets
2. **Database**: RDS in private subnet only
3. **Access**: Bastion host for SSH or SSM Session Manager
4. **Secrets**: Variables (can upgrade to Secrets Manager)
5. **Monitoring**: CloudWatch native monitoring

---

## Security Considerations

### Network Security

```
ALB Security Group:
  - Inbound: 80, 443 from 0.0.0.0/0
  - Outbound: All to EC2 SG

EC2 Security Group:
  - Inbound: 80, 443 from ALB SG
  - Inbound: 22 from Bastion SG
  - Outbound: All

RDS Security Group:
  - Inbound: 5432 from EC2 SG only
  - Outbound: None
```

### Data Security

- Encryption at rest (RDS with KMS)
- Encryption in transit (SSL enabled)
- IAM role-based access (no hardcoded credentials)
- Automated backups (7-day retention)

---

## Cost Optimization

### Monthly Cost Estimate

| Component | Cost |
|-----------|------|
| EC2 (t3.micro) | $7.50 |
| RDS (db.t3.micro) | $30.00 |
| ALB | $16.20 |
| NAT Gateway | $32.00 |
| Data Transfer | $5.00 |
| **TOTAL** | **~$90.70** |

### Optimization Strategies

1. Use t3.micro instances (free tier eligible)
2. Single AZ deployment
3. gp3 storage instead of gp2
4. 7-day backup retention
5. Private subnets reduce NAT costs

---

## Troubleshooting

### Issue: Terraform Apply Fails

```bash
# Check AWS credentials
aws sts get-caller-identity

# Validate Terraform files
terraform validate
```

### Issue: EC2 Can't Reach RDS

```bash
# Verify security groups in AWS console
# Ensure RDS is in same VPC
# Test connectivity from EC2

psql -h <rds-endpoint> -U admin -d postgres
```

### Issue: Bastion Unreachable

```bash
# Check your IP in security group
curl ifconfig.me

# Update bastion_allowed_cidrs in variables
```

---

## Additional Resources

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Security Best Practices](https://docs.aws.amazon.com/security/)

---

## File Descriptions

### terraform/main.tf
- VPC and networking configuration
- EC2 instances and load balancers
- RDS database configuration
- Internet Gateway and NAT Gateway

### terraform/security.tf
- Security group definitions
- IAM roles and policies
- Access control configuration

### terraform/variables.tf
- Input variables with validation
- Default values for easy customization
- Sensitive variable handling

### terraform/outputs.tf
- Important resource identifiers
- Connection strings and endpoints
- Application URLs

### scripts/health-check.sh
- System monitoring script
- Disk, memory, and Docker checks
- Timestamped logging

### diagrams/architecture-diagram.md
- Visual architecture representation
- Network flow diagrams
- Security boundaries

