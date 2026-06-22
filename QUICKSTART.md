# Quick Start Guide

## 1. Clone Repository
```bash
git clone <your-repo> devops-assignment
cd devops-assignment
```

## 2. Configure AWS
```bash
aws configure
# Enter credentials and default region
```

## 3. Prepare Terraform
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars

# Edit with your values:
nano terraform.tfvars
# - Change db_password
# - Change bastion_allowed_cidrs to YOUR_IP/32
# - Optionally adjust other settings
```

## 4. Deploy Infrastructure
```bash
# Initialize Terraform
terraform init

# Review plan
terraform plan

# Apply configuration
terraform apply
```

## 5. Get Access Information
```bash
# Export outputs
terraform output -json > outputs.json

# Get application URL
terraform output application_url

# Get database connection info
terraform output rds_connection_string

# Get bastion IP (if enabled)
terraform output bastion_public_ip
```

## 6. Test Application
```bash
# Get ALB DNS
APP_URL=$(terraform output -raw application_url)

# Test connectivity
curl "$APP_URL"
```

## 7. Connect to EC2
```bash
# Option 1: Via Bastion
BASTION_IP=$(terraform output -raw bastion_public_ip)
ssh -i your-key.pem ec2-user@$BASTION_IP

# From Bastion:
ssh -i your-key.pem ec2-user@<ec2-private-ip>

# Option 2: Via SSM Session Manager
aws ssm start-session --target <instance-id>
```

## 8. Run Health Check
```bash
# SSH into EC2
ssh -i your-key.pem ec2-user@<ec2-ip>

# Run health check
/usr/local/bin/health-check.sh

# View logs
tail -f /var/log/health-check/health-check.log
```

## 9. Cleanup
```bash
# Destroy all resources
terraform destroy

# Verify deletion
aws ec2 describe-vpcs --filters "Name=cidr,Values=10.0.0.0/16"
```

---

## Environment Variables

For automation, set these before running terraform:

```bash
export AWS_REGION="us-east-1"
export AWS_PROFILE="default"
export TF_VAR_db_password="YourSecurePassword123!"
export TF_VAR_bastion_allowed_cidrs='["YOUR.IP.ADDRESS/32"]'
```

## Troubleshooting

### AWS Credentials Issue
```bash
aws sts get-caller-identity
# Should show your account info
```

### Terraform State Issue
```bash
# Reinitialize terraform
rm -rf .terraform/
terraform init
```

### VPC/Subnet Conflict
```bash
# Check existing VPCs
aws ec2 describe-vpcs

# Change CIDR in terraform.tfvars if conflict exists
vpc_cidr = "10.1.0.0/16"  # Different range
`
```
