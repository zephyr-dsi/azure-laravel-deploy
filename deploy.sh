#!/bin/bash

# Ajouter le dépôt PHP
add-apt-repository ppa:ondrej/php -y
apt-get update

# Installer les paquets
apt-get install -y nginx php8.2 php8.2-fpm php8.2-mysql php8.2-cli php8.2-mbstring php8.2-xml php8.2-zip unzip curl git

# Installer Composer
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Configurer Nginx
cat > /etc/nginx/sites-available/laravel <<EOF
server {
    listen 80;
    server_name _;
    root /var/www/laravel/public;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# Activer la configuration Nginx
rm -f /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/laravel /etc/nginx/sites-enabled/
systemctl reload nginx

# Déployer Laravel
mkdir -p /var/www
cd /var/www
composer create-project --prefer-dist laravel/laravel laravel
chown -R www-data:www-data /var/www/laravel
chmod -R 755 /var/www/laravel

# Générer la clé Laravel
cd /var/www/laravel
php artisan key:generate

# Configurer les permissions
chmod -R 775 storage bootstrap/cache

# Pare-feu
ufw allow OpenSSH
ufw allow 80
echo "y" | ufw enable

# Redémarrer les services
systemctl enable --now nginx php8.2-fpm
