#!/bin/bash

# Update and Upgrade Packages
apt-get update -y && apt-get upgrade -y

# Install Required Packages
apt-get install -y docker.io mailutils zip

# Install docker-compose
curl -L "https://github.com/docker/compose/releases/download/2.29.1/docker-compose-linux-x86_64" \
  -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create new user 'ghostuser' and authorized_keys
useradd -m -s /bin/bash ghostuser
mkdir -p /home/ghostuser/.ssh
cp /home/ubuntu/.ssh/authorized_keys /home/ghostuser/.ssh/
chown -R ghostuser:ghostuser /home/ghostuser/.ssh
chmod 700 /home/ghostuser/.ssh
chmod 600 /home/ghostuser/.ssh/authorized_keys

# Add new user to Docker Group
usermod -aG docker ghostuser

# Configure Firewall
ufw allow OpenSSH
ufw allow 80
ufw allow https
ufw --force enable

# Create Directories for Ghost Application and Data Volumes
mkdir -p /home/ghostuser/ghost/ghost_content
mkdir -p /home/ghostuser/ghost/db_data
chown -R ghostuser:ghostuser /home/ghostuser/ghost

# Switch to 'ghostuser'
su - ghostuser <<'EOF'

# Navigate to Ghost Application Directory
cd ~/ghost

# Create docker-compose.yml
cat <<'EOL' > docker-compose.yml
version: '3.8'
services:
  ghost:
    image: ghost:latest
    container_name: ghost
    ports:
      - "80:2368"
    depends_on:
      db:
        condition: service_healthy
    environment:
      database__client: mysql
      database__connection__host: db
      database__connection__user: ghost
      database__connection__password: ghost_password
      database__connection__database: ghost_db
    volumes:
      - /home/ghostuser/ghost/ghost_content:/var/lib/ghost/content
    restart: always

  db:
    image: mysql:8.0
    container_name: db
    restart: always
    environment:
      MYSQL_DATABASE: ghost_db
      MYSQL_USER: ghost
      MYSQL_PASSWORD: ghost_password
      MYSQL_ROOT_PASSWORD: root_password
    volumes:
      - /home/ghostuser/ghost/db_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "--silent"]
      interval: 10s
      timeout: 5s
      retries: 5
EOL

# Start Docker Compose
docker compose up -d

EOF

# Create Backup Directory
mkdir -p /backup
chown ghostuser:ghostuser /backup
chmod 700 /backup

# Create Scripts Directory
mkdir -p /home/ghostuser/backup_scripts
chown ghostuser:ghostuser /home/ghostuser/backup_scripts

# Create Backup Script
cat <<'EOF' > /home/ghostuser/backup_scripts/backup_ghost.sh
#!/bin/bash

# Variables
TIMESTAMP=$(date +"%F")
BACKUP_DIR="/backup"
GHOST_CONTENT_DIR="/home/ghostuser/ghost/ghost_content"
MYSQL_DATA_DIR="/home/ghostuser/ghost/db_data"
MYSQL_USER="ghost"
MYSQL_PASSWORD="ghost_password"
MYSQL_DATABASE="ghost_db"
EMAIL="your_email@example.com"

# Ensure the backup directory exists
mkdir -p "$BACKUP_DIR"

# Dump the MySQL database
docker exec db mysqldump -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" > "$BACKUP_DIR/${MYSQL_DATABASE}_$TIMESTAMP.sql"

# Compress the Ghost content directory
zip -r "$BACKUP_DIR/ghost_content_$TIMESTAMP.zip" "$GHOST_CONTENT_DIR"

# Create a summary file
SUMMARY_FILE="$BACKUP_DIR/backup_summary_$TIMESTAMP.txt"
echo "Backup completed for $TIMESTAMP" > "$SUMMARY_FILE"
echo "Database backup: ${MYSQL_DATABASE}_$TIMESTAMP.sql" >> "$SUMMARY_FILE"
echo "Content backup: ghost_content_$TIMESTAMP.zip" >> "$SUMMARY_FILE"

# Send email summary
mail -s "Ghost Backup Summary for $TIMESTAMP" "$EMAIL" < "$SUMMARY_FILE"
EOF

# Replace placeholder email in backup script
sed -i 's/your_email@example.com/your_actual_email@example.com/g' /home/ghostuser/backup_scripts/backup_ghost.sh

# Make the Backup Script Executable
chmod +x /home/ghostuser/backup_scripts/backup_ghost.sh
chown ghostuser:ghostuser /home/ghostuser/backup_scripts/backup_ghost.sh

# Add cron job to the crontab of 'ghostuser'
(crontab -l -u ghostuser 2>/dev/null; echo "0 16 * * * /home/ghostuser/backup_scripts/backup_ghost.sh >> /home/ghostuser/backup_scripts/backup.log 2>&1") | crontab -u ghostuser -
