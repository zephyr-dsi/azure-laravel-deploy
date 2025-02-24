#!/bin/bash
set -euo pipefail

# 1. Mise à jour et installation des dépendances
apt-get update
apt-get install -y software-properties-common curl git
add-apt-repository ppa:ondrej/php -y
apt-get update
apt-get install -y nginx php8.2-fpm php8.2-mysql php8.2-mbstring php8.2-xml php8.2-zip php8.2-bcmath

# 2. Configuration Nginx
cat > /etc/nginx/sites-available/laravel <<'EOF'
server {
    listen 80;
    server_name _;
    root /var/www/laravel/public;
    index index.php index.html index.htm;

    location / {
        try_files $uri $uri/ "/index.php?$query_string";
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# 3. Activation de la config Nginx
ln -sf /etc/nginx/sites-available/laravel /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx

# 4. Installation de Composer
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# 5. Déploiement de Laravel
mkdir -p /var/www
cd /var/www
composer create-project --prefer-dist laravel/laravel laravel
chown -R www-data:www-data laravel
cd laravel
php artisan key:generate --force
chmod -R 775 storage bootstrap/cache

# 6. Pare-feu
ufw allow OpenSSH
ufw allow 80
yes | ufw enable

# 7. Démarrage des services
systemctl enable --now nginx php8.2-fpm

echo "Déploiement réussi ! Accès : http://$(hostname -I | awk '{print $1}')"
