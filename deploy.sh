#!/bin/bash
set -euo pipefail

echo "📝 Journalisation des étapes..."
exec > >(tee /var/log/vm_setup.log) 2>&1

echo "🔄 Mise à jour des paquets..."
sudo apt update -qq && sudo apt upgrade -y

echo "📦 Installation des dépendances de base..."
sudo apt install -y software-properties-common curl git unzip supervisor cron redis-server

echo "📦 Installation de Node.js et NPM..."
curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
sudo apt install -y nodejs

echo "📦 Ajout du dépôt PHP 8.2 et installation..."
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update -qq
sudo apt install -y nginx php8.2 php8.2-fpm php8.2-mbstring php8.2-xml php8.2-zip php8.2-bcmath

echo "📦 Installation de Composer..."
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

echo "🚀 Déploiement de Laravel..."
sudo mkdir -p /var/www
cd /var/www
yes | composer create-project --prefer-dist laravel/laravel laravel --no-interaction --optimize-autoloader --no-dev

if [ ! -d "/var/www/laravel" ]; then
    echo "❌ Échec de l'installation de Laravel."
    exit 1
fi

echo "🔧 Configuration des permissions pour Laravel..."
sudo chown -R www-data:www-data /var/www/laravel
sudo chmod -R 775 /var/www/laravel/storage /var/www/laravel/bootstrap/cache /var/www/laravel/vendor

echo "🔑 Génération de la clé Laravel..."
cd /var/www/laravel
yes | php artisan key:generate --force

echo "🔧 Configuration de Nginx pour Laravel..."
sudo tee /etc/nginx/sites-available/laravel > /dev/null <<'EOF'
server {
    listen 80;
    server_name _;

    root /var/www/laravel/public;
    index index.php index.html index.htm;

    server_tokens off;
    fastcgi_hide_header X-Powered-By;

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }

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

echo "🔧 Activation de la configuration Nginx..."
sudo ln -sf /etc/nginx/sites-available/laravel /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx

echo "🔧 Configuration de Supervisor pour les workers Laravel..."
sudo tee /etc/supervisor/conf.d/laravel-worker.conf > /dev/null <<'EOF'
[program:laravel-worker]
command=php /var/www/laravel/artisan queue:work --sleep=3 --tries=3
autostart=true
autorestart=true
user=www-data
numprocs=2
redirect_stderr=true
stdout_logfile=/var/www/laravel/storage/logs/worker.log
EOF

echo "🔧 Redémarrage de Supervisor..."
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start laravel-worker:*

echo "🔧 Activation et redémarrage des services..."
sudo systemctl restart nginx php8.2-fpm supervisor cron redis-server

echo "✅ Vérification des versions installées..."
nginx -v
php -v
composer --version
node -v
npm -v
git --version
curl --version
redis-server --version
supervisord -v

echo "✅ Déploiement réussi ! Accès : http://$(hostname -I | awk '{print $1}')"
