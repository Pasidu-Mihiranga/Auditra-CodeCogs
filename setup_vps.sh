#!/bin/bash

# Exit on any error
set -e

echo "=== Starting VPS Setup for Auditra ==="

# 1. Create Systemd Service for Daphne (ASGI server)
echo "Creating auditra-daphne.service..."
cat <<EOT | sudo tee /etc/systemd/system/auditra-daphne.service > /dev/null
[Unit]
Description=Daphne ASGI Server for Auditra
After=network.target

[Service]
User=root
Group=www-data
WorkingDirectory=/var/www/auditra/backend
ExecStart=/var/www/auditra/backend/venv/bin/daphne -b 127.0.0.1 -p 8000 auditra_backend.asgi:application
Restart=always

[Install]
WantedBy=multi-user.target
EOT

# 2. Create Systemd Service for Celery Worker
echo "Creating auditra-celery.service..."
cat <<EOT | sudo tee /etc/systemd/system/auditra-celery.service > /dev/null
[Unit]
Description=Celery Worker for Auditra
After=network.target

[Service]
User=root
Group=www-data
WorkingDirectory=/var/www/auditra/backend
ExecStart=/var/www/auditra/backend/venv/bin/celery -A auditra_backend worker -l info
Restart=always

[Install]
WantedBy=multi-user.target
EOT

# 3. Create Systemd Service for Celery Beat
echo "Creating auditra-celerybeat.service..."
cat <<EOT | sudo tee /etc/systemd/system/auditra-celerybeat.service > /dev/null
[Unit]
Description=Celery Beat for Auditra
After=network.target

[Service]
User=root
Group=www-data
WorkingDirectory=/var/www/auditra/backend
ExecStart=/var/www/auditra/backend/venv/bin/celery -A auditra_backend beat -l info
Restart=always

[Install]
WantedBy=multi-user.target
EOT

# 4. Create Nginx Configuration
echo "Creating Nginx configuration..."
cat <<EOT | sudo tee /etc/nginx/sites-available/auditra > /dev/null
server {
    listen 80;
    server_name auditra.pasidumihiranga.me;
    client_max_body_size 10M;

    # Serve React Frontend
    location / {
        root "/var/www/auditra/auditra web app/dist";
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }

    # Serve Media Files (Profile Avatars, etc.)
    location /media/ {
        alias /var/www/auditra/backend/media/;
    }

    # Proxy API Requests to Daphne (Django ASGI)
    location /api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Proxy Django Admin (Optional)
    location /admin/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # WebSockets (Django Channels)
    location /ws/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOT

# 5. Enable Nginx configuration
echo "Enabling Nginx configuration..."
sudo ln -sf /etc/nginx/sites-available/auditra /etc/nginx/sites-enabled/

# Remove default site if it exists to avoid conflicts
if [ -f /etc/nginx/sites-enabled/default ]; then
    echo "Disabling default Nginx site..."
    sudo rm /etc/nginx/sites-enabled/default
fi

# 6. Reload Systemd and start/enable services
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "Enabling services on boot..."
sudo systemctl enable auditra-daphne
sudo systemctl enable auditra-celery
sudo systemctl enable auditra-celerybeat

echo "Starting/Restarting services..."
# We use restart here just in case they were already running
sudo systemctl restart auditra-daphne || echo "Service auditra-daphne failed to start, will start after deployment files exist."
sudo systemctl restart auditra-celery || echo "Service auditra-celery failed to start, will start after deployment files exist."
sudo systemctl restart auditra-celerybeat || echo "Service auditra-celerybeat failed to start, will start after deployment files exist."

echo "Testing Nginx configuration..."
sudo nginx -t

echo "Restarting Nginx..."
sudo systemctl restart nginx

echo "=== VPS Setup Complete ==="
