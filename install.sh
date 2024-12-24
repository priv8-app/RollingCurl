#!/bin/bash

# Warna ANSI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Fungsi untuk menampilkan pesan dengan warna
function info {
    echo -e "${CYAN}[INFO]${RESET} $1"
}

function success {
    echo -e "${GREEN}[SUCCESS]${RESET} $1"
}

function error {
    echo -e "${RED}[ERROR]${RESET} $1"
}

function warn {
    echo -e "${YELLOW}[WARNING]${RESET} $1"
}

# Validasi argumen
if [ -z "$1" ]; then
    error "Domain name is required. Usage: ./install.sh yourdomain.com"
    exit 1
fi

DOMAIN=$1
CONFIG_PATH="/etc/apache2/sites-available/${DOMAIN}.conf"
DOC_ROOT="/var/www/${DOMAIN}"

info "Using domain: $DOMAIN"

# Update dan upgrade sistem
info "Updating and upgrading system..."
if sudo apt update && sudo apt upgrade -y; then
    success "System updated and upgraded."
else
    error "Failed to update and upgrade the system."
    exit 1
fi

# Install Apache2
info "Installing Apache2 And PHP..."
if sudo apt install apache2 -y && apt install php -y && apt install php-curl -y; then
    success "Apache2 installed successfully."
else
    error "Failed to install Apache2."
    exit 1
fi

# Install Certbot dan modul Apache untuk SSL
info "Installing Certbot and Apache module for SSL..."
if sudo apt install certbot python3-certbot-apache -y; then
    success "Certbot and Apache SSL module installed."
else
    error "Failed to install Certbot or Apache SSL module."
    exit 1
fi

info "Checking Certbot version..."
certbot --version

# Konfigurasi VirtualHost untuk domain
info "Creating VirtualHost configuration for $DOMAIN..."
sudo mkdir -p $DOC_ROOT
sudo chown -R $USER:$USER $DOC_ROOT
sudo chmod -R 755 $DOC_ROOT

cat <<EOF | sudo tee $CONFIG_PATH
<VirtualHost *:80>
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    DocumentRoot $DOC_ROOT

    <Directory $DOC_ROOT>
        AllowOverride All
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/${DOMAIN}_error.log
    CustomLog \${APACHE_LOG_DIR}/${DOMAIN}_access.log combined
</VirtualHost>
EOF

success "VirtualHost configuration created."

# Aktifkan VirtualHost dan mod_rewrite
info "Enabling site and rewrite module..."
sudo a2ensite $DOMAIN.conf
sudo a2enmod rewrite
sudo systemctl reload apache2
success "Site enabled and mod_rewrite activated."

# Konfigurasi SSL dengan Certbot
info "Configuring SSL with Certbot..."
if sudo certbot --apache -d $DOMAIN; then
    success "SSL configured successfully."
else
    error "Failed to configure SSL."
    exit 1
fi

# Tes konfigurasi Apache
info "Testing Apache configuration..."
if sudo apachectl configtest; then
    success "Apache configuration test passed."
else
    error "Apache configuration test failed."
    exit 1
fi

# Restart Apache
info "Restarting Apache..."
sudo systemctl restart apache2
success "Apache restarted successfully."

# Tes pembaruan sertifikat
info "Testing SSL certificate renewal..."
if sudo certbot renew --dry-run; then
    success "SSL certificate renewal test successful."
else
    warn "SSL certificate renewal test failed. Please check Certbot logs."
fi

# Ubah izin folder ke www-data
info "Setting ownership and permissions for $DOC_ROOT..."
sudo chown -R www-data:www-data $DOC_ROOT
sudo chmod -R 755 $DOC_ROOT
success "Ownership and permissions set for $DOC_ROOT."

success "Installation and configuration for $DOMAIN completed successfully!"
