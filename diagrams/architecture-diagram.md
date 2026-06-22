```
                              ┌─────────────────────────────────┐
                              │     INTERNET (0.0.0.0/0)        │
                              └────────────────┬────────────────┘
                                              │
                                    ┌─────────▼────────────┐
                                    │   Route 53 (DNS)     │
                                    │  devops-app.com      │
                                    └─────────┬────────────┘
                                              │
                              ┌───────────────▼──────────────┐
                              │      AWS Region: us-east-1   │
                              │   ┌────────────────────────┐  │
                              │   │ Internet Gateway (IGW) │  │
                              │   │   Attached to VPC      │  │
                              │   └────────┬───────────────┘  │
                              │            │                  │
                              │   ┌────────▼───────────────┐  │
                              │   │  VPC: 10.0.0.0/16      │  │
                              │   │                        │  │
           ┌────────SG────────┤   │ ┌──────────────────┐   │  │
           │ ALB Rules        │   │ │  PUBLIC SUBNET   │   │  │
           │ IN:80,443        │   │ │  10.0.1.0/24     │   │  │
           │ OUT:All          │   │ │  (AZ: us-east-1a)│   │  │
           └────────┬─────────┤   │ │                  │   │  │
                    │         │   │ │ ┌──────────────┐ │   │  │
                    │         │   │ │ │     ALB      │ │   │  │
                    │         │   │ │ │   (:80/443)  │ │   │  │
                    │         │   │ │ │              │ │   │  │
    ┌───────────────▼─────────┤   │ │ └────┬─────────┘ │   │  │
    │                         │   │ │      │           │   │  │
    │  Target Group:          │   │ │ ┌────▼────────┐  │   │  │
    │  Health Check ✓         │   │ │ │ Bastion     │  │   │  │
    │  Sticky Sessions        │   │ │ │ Host        │  │   │  │
    │                         │   │ │ │ (:22)       │  │   │  │
    │  ┌─────────────────────┤   │ │ │ │(t3.micro)  │  │   │  │
    │  │                     │   │ │ │ └────────────┘  │   │  │
    │  │                     │   │ │ └──────────────────┘   │  │
    │  │                     │   │ │                        │  │
    │  │                     │   │ │ ┌──────────────────┐   │  │
    │  │                     │   │ │ │  PRIVATE SUBNET  │   │  │
    │  │                     │   │ │ │  10.0.2.0/24     │   │  │
    │  │                     │   │ │ │(AZ: us-east-1a)  │   │  │
    │  │                     │   │ │ │                  │   │  │
    │  │                     │   │ │ │ ┌──────────────┐ │   │  │
    └──┼──────────────────────┤   │ │ │ │ EC2 Instance│ │   │  │
       │                      │   │ │ │ │  (App:80)   │ │   │  │
  ┌────▼────────────────────┐ │   │ │ │ │ t3.micro   │ │   │  │
  │                         │ │   │ │ │ │            │ │   │  │
  │ EC2 SG Rules           │ │   │ │ │ │IAM Role:   │ │   │  │
  │ IN:80,443 (from ALB)  │ │   │ │ │ │  ├─ECR      │ │   │  │
  │ IN:22 (from Bastion)  │ │   │ │ │ │  ├─CW Logs  │ │   │  │
  │ OUT:All               │ │   │ │ │ │  ├─Secrets  │ │   │  │
  │                       │ │   │ │ │ │  └─SSM      │ │   │  │
  │ ┌──────────────────┐  │ │   │ │ │ └──────────────┘ │   │  │
  │ │ Application Code │  │ │   │ │ │                  │   │  │
  │ │ (Nginx/Docker)   │  │ │   │ │ │ ┌──────────────┐ │   │  │
  │ │                  │  │ │   │ │ │ │     NAT      │ │   │  │
  │ │ Ports:           │  │ │   │ │ │ │   Gateway    │ │   │  │
  │ │  80:HTTP         │  │ │   │ │ │ │ (Outbound)   │ │   │  │
  │ │  443:HTTPS       │  │ │   │ │ │ └──────────────┘ │   │  │
  │ └────┬─────────────┘  │ │   │ │ └──────────────────┘   │  │
  │      │                │ │   │ │                        │  │
  │      │ (TCP 5432)     │ │   │ │ ┌──────────────────┐   │  │
  │      │                │ │   │ │ │ RDS Subnet Grp   │   │  │
  │      └────────┬───────┼─┤   │ │ │  (Private only)  │   │  │
  │               │       │ │   │ │ │                  │   │  │
  │ ┌─────────────▼──────┐│ │   │ │ │ ┌──────────────┐ │   │  │
  │ │ RDS SG Rules       ││ │   │ │ │ │  RDS         │ │   │  │
  │ │ IN:5432(from EC2)  ││ │   │ │ │ │  PostgreSQL  │ │   │  │
  │ │ OUT:None           ││ │   │ │ │ │              │ │   │  │
  │ └────────────────────┘│ │   │ │ │ │ db.t3.micro  │ │   │  │
  │                       │ │   │ │ │ │              │ │   │  │
  └───────────────────────┼─┤   │ │ │ │ Encryption:  │ │   │  │
                          │ │   │ │ │ │  ├─At Rest    │ │   │  │
                          │ │   │ │ │ │  ├─In Transit │ │   │  │
                          │ │   │ │ │ │  └─Automated  │ │   │  │
                          │ │   │ │ │ │    Backups    │ │   │  │
                          │ │   │ │ │ │    (7 days)   │ │   │  │
                          │ │   │ │ │ └──────────────┘ │   │  │
                          │ │   │ │ └──────────────────┘   │  │
                          │ │   │ │                        │  │
                          │ │   │ │ CloudWatch Metrics/    │  │
                          │ │   │ │ Logs Integration       │  │
                          │ │   │ └────────────────────────┘  │
                          │ │                                 │
                          │ └─────────────────────────────────┘
                          │
                          └──────────── All traffic encrypted  
                                        where possible
```

## Network Flow Diagram

### Inbound Request (User → Application)

```
Internet User
    ↓ (HTTP/HTTPS)
Route 53 DNS
    ↓ (resolves to ALB DNS)
ALB (10.0.1.x:80/443)
    ↓ (internal routing)
EC2 Instance (10.0.2.x:80)
    ↓ (application logic)
RDS (10.0.2.x:5432)
    ↓ (SQL query)
Database
    ↓ (response)
EC2 Instance
    ↓ (HTTP response)
ALB
    ↓ (HTTP response)
Internet User
```

### Administrative Access (Bastion → EC2)

```
Admin's Workstation
    ↓ (SSH to Bastion public IP)
Bastion Host (10.0.1.x:22)
    ↓ (SSH from Bastion to EC2 private IP)
EC2 Instance (10.0.2.x:22)
    ↓ (Interactive shell)
Admin Terminal
```

### Alternative: SSM Session Manager

```
AWS Console / AWS CLI
    ↓
IAM Authentication
    ↓
Systems Manager Session Manager
    ↓ (encrypted session)
EC2 Instance (no SSH key needed)
    ↓
Admin Terminal
```

---

## Security Boundaries

```
┌─────────────────────────────────────────────────────────────┐
│                        INTERNET (Public)                    │
└──────────────────────────┬──────────────────────────────────┘
                           │
                   ┌───────▼────────┐
                   │ VPC Boundary   │
                   │ (Firewall)     │
                   └───────┬────────┘
                           │
            ┌──────────────▼──────────────┐
            │   PUBLIC SECURITY ZONE      │
            │  (Bastion, ALB, NAT GW)     │
            │  Direct Internet Access ✓   │
            └──────────────┬──────────────┘
                           │
            ┌──────────────▼──────────────┐
            │ APPLICATION SECURITY ZONE   │
            │   (EC2 Instances)           │
            │ Private Subnet Access only  │
            │   No direct internet ✗      │
            └──────────────┬──────────────┘
                           │
            ┌──────────────▼──────────────┐
            │  DATABASE SECURITY ZONE     │
            │      (RDS Instance)         │
            │  EC2-only access            │
            │   Encrypted connections     │
            │   No external access ✗      │
            └─────────────────────────────┘
```
