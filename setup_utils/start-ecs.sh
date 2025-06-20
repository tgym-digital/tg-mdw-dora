#!/bin/bash

echo 'MHQ_EXTRACT_BACKEND_DEPENDENCIES'
if [ -f /opt/venv.tar.gz ]; then
    mkdir -p /opt/venv
    tar xzf /opt/venv.tar.gz -C /opt/venv --strip-components=2
    rm -rf /opt/venv.tar.gz
else
    echo "Tar file /opt/venv.tar.gz does not exist. Skipping extraction."
fi

echo 'MHQ_EXTRACT_FRONTEND'
if [ -f /app/web-server.tar.gz ]; then
    mkdir -p /app/web-server
    tar xzf /app/web-server.tar.gz -C /app/web-server --strip-components=2
    rm -rf /app/web-server.tar.gz
else
    echo "Tar file /app/web-server.tar.gz does not exist. Skipping extraction."
fi

echo 'MHQ_SETUP_EFS_MOUNTS'

# Setup EFS mounts for persistent data
if [ -d "/efs/postgres_data" ]; then
    echo "Setting up PostgreSQL data directory on EFS..."
    # Create symlink to EFS mount for PostgreSQL data
    mkdir -p /efs/postgres_data/main
    ln -sf /efs/postgres_data/main /var/lib/postgresql/15/main
    chown -R postgres:postgres /efs/postgres_data
    chmod 700 /efs/postgres_data/main
fi

if [ -d "/efs/config" ]; then
    echo "Setting up config directory on EFS..."
    # Create symlink to EFS mount for config
    mkdir -p /efs/config
    ln -sf /efs/config /app/backend/analytics_server/mhq/config
fi

if [ -d "/efs/logs" ]; then
    echo "Setting up logs directory on EFS..."
    # Create symlink to EFS mount for logs
    mkdir -p /efs/logs
    ln -sf /efs/logs /var/log
fi

echo 'MHQ_STARTING SUPERVISOR'

if [ -f "/app/backend/analytics_server/mhq/config/config.ini" ]; then
  echo "config.ini found. Setting environment variables from config.ini..."
    while IFS='=' read -r key value; do
        if [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ && ! -z "$value" ]]; then
            echo "$key"="$value" >> ~/.bashrc
        fi
    done < "../backend/analytics_server/mhq/config/config.ini"
else
    echo "config.ini not found. Running generate_config_ini.sh..."
    /app/setup_utils/generate_config_ini.sh -t /app/backend/analytics_server/mhq/config
fi

source ~/.bashrc

/usr/bin/supervisord -c "/etc/supervisord.conf" 