#!/bin/bash

# Update and Upgrade Packages
apt-get update -y && apt-get upgrade -y

# Install Docker and Docker-Compose
apt-get install -y docker.io docker-compose

# Add 'ubuntu' User to Docker Group
usermod -aG docker ubuntu

# Create Directory for Ghost Application
mkdir -p /home/ubuntu/ghost
cd /home/ubuntu/ghost

# Copy docker-compose.yml (Assuming it's baked into the AMI or use SSM to send)
cat <<'EOF' > docker-compose.yml
version: '3'
services:
  mysql:
    image: docker.io/bitnami/mysql:8.4
    volumes:
      - 'mysql_data:/bitnami/mysql'
    environment:
      # ALLOW_EMPTY_PASSWORD is recommended only for development.
      - ALLOW_EMPTY_PASSWORD=yes
      - MYSQL_USER=bn_ghost
      - MYSQL_DATABASE=bitnami_ghost
  ghost:
    image: docker.io/bitnami/ghost:5
    ports:
      - '80:2368'
    volumes:
      - 'ghost_data:/bitnami/ghost'
    depends_on:
      - mysql
    environment:
      # ALLOW_EMPTY_PASSWORD is recommended only for development.
      - ALLOW_EMPTY_PASSWORD=yes
      - GHOST_DATABASE_HOST=mysql
      - GHOST_DATABASE_PORT_NUMBER=3306
      - GHOST_DATABASE_USER=bn_ghost
      - GHOST_DATABASE_NAME=bitnami_ghost
volumes:
  mysql_data:
    driver: local
  ghost_data:
    driver: local
EOF

# Start Docker-Compose as 'ubuntu' User
chown -R ubuntu:ubuntu /home/ubuntu/ghost
su - ubuntu -c "cd /home/ubuntu/ghost && docker-compose up -d"
