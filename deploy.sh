#!/bin/bash
set -e  # Arrêter le script en cas d'erreur
set -x  # Afficher les commandes exécutées

# 1. Prérequis système
apt-get install -y software-properties-common curl git

# 2. Configuration des dépôts
add-apt-repository ppa:ondrej/php -y
apt-get update

# 3. Installation des paquets
apt-get install -y \
    nginx \
    php8.2 \
    php8.2-fpm \
    php8.2-mysql \
    php8.2-mbstring \
    php8.2-xml \
    php8.2-zip \
    php8.2-bcmath \
    unzip

# 4. Installation de Composer
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# 5. Configuration Nginx
cat > /etc/nginx/sites-available/laravel <<'EOF'
server {
    listen 80;
    server_name _;
    root /var/www/laravel/public;
    index index.php index.html index.htm;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
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

# 6. Activation de la configuration
rm -f /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/laravel /etc/nginx/sites-enabled/
nginx -t  # Validation de la configuration
systemctl reload nginx

# 7. Déploiement de Laravel
mkdir -p /var/www
cd /var/www
composer create-project --prefer-dist laravel/laravel laravel

# 8. Permissions
chown -R www-data:www-data /var/www/laravel
chmod -R 755 /var/www/laravel
cd /var/www/laravel
php artisan key:generate
chmod -R 775 storage bootstrap/cache

# 9. Pare-feu
ufw allow OpenSSH
ufw allow 80
echo "y" | ufw enable

# 10. Démarrage des services
systemctl enable --now nginx php8.2-fpm

echo "Déploiement réussi! Accédez à http://<ip-publique-vm>"
