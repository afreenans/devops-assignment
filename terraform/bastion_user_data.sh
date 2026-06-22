#!/bin/bash

# Update system
yum update -y

# Install useful tools
yum install -y \
  postgresql \
  mysql \
  docker \
  git \
  curl \
  wget \
  net-tools \
  htop

# Start Docker
systemctl start docker
systemctl enable docker

# Install AWS CLI v2
yum install -y unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws/

# Install Session Manager plugin
yum install -y session-manager-plugin

echo "Bastion setup complete" > /var/log/bastion-setup.log
