#!/bin/bash
set -euo pipefail  # Gestion stricte des erreurs

# 1. Installer les dépendances système
apt-get update
apt-get install -y software-properties-common curl git

# 2. Ajouter le dépôt PHP
LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
apt-get update

# 3. Installer les paquets
apt-get install -y \
    nginx \
    php8.2-fpm \
    php8.2-mysql \
    php8.2-mbstring \
    php8.2-xml \
    php8.2-zip \
    php8.2-bcmath

# 4. Installer Composer (dernière version)
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer --2

# 5. Configurer Nginx (échappement des variables avec \)
cat > /etc/nginx/sites-available/laravel <<'EOF'
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

# 6. Valider et activer la config Nginx
nginx -t  # Test de syntaxe
rm -f /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/laravel /etc/nginx/sites-enabled/
systemctl reload nginx

# 7. Déployer Laravel
mkdir -p /var/www
cd /var/www
composer create-project --prefer-dist laravel/laravel laravel

# 8. Appliquer les permissions
chown -R www-data:www-data /var/www/laravel
chmod -R 755 /var/www/laravel
cd /var/www/laravel
php artisan key:generate --force
chmod -R 775 storage bootstrap/cache

# 9. Configurer le pare-feu
ufw allow OpenSSH
ufw allow 80
yes | ufw enable

# 10. Démarrer les services
systemctl enable --now nginx php8.2-fpm

echo "Déploiement terminé ! Accès : http://$(curl -s ifconfig.me)"
