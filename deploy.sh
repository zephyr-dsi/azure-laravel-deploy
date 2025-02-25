#!/bin/bash
set -euo pipefail

# Fonction pour afficher un titre stylisé
function print_title {
    echo -e "\n\033[1;36m========================================\033[0m"
    echo -e "\033[1;36m$1\033[0m"
    echo -e "\033[1;36m========================================\033[0m\n"
}

# Fonction pour afficher une barre de progression
function show_progress {
    local duration=${1}
    local steps=${2}
    local step=0

    while [ $step -lt $steps ]; do
        echo -n "."
        sleep $duration
        step=$((step + 1))
    done
    echo -e "\n"
}

# Afficher le titre du script
print_title "🛠️ Script de déploiement d'une application Laravel sur Azure 🚀"

# Afficher la liste des éléments qui seront installés et configurés
echo -e "\033[1;33m📋 Liste des éléments qui seront installés et configurés :\033[0m"
echo -e "\033[1;32m- Mise à jour des paquets système\033[0m"
echo -e "\033[1;32m- Installation des dépendances de base :\033[0m"
echo -e "  - \033[1;34msoftware-properties-common\033[0m (pour gérer les dépôts PPAs)"
echo -e "  - \033[1;34mcurl\033[0m (pour télécharger des fichiers depuis Internet)"
echo -e "  - \033[1;34mgit\033[0m (pour cloner des dépôts et gérer le versionnement)"
echo -e "  - \033[1;34munzip\033[0m (pour décompresser des fichiers)"
echo -e "  - \033[1;34msupervisor\033[0m (pour gérer les processus en arrière-plan)"
echo -e "  - \033[1;34mcron\033[0m (pour exécuter des tâches planifiées)"
echo -e "  - \033[1;34mredis-server\033[0m (pour le cache et les files d'attente)"
echo -e "\033[1;32m- Installation de Node.js et NPM\033[0m"
echo -e "\033[1;32m- Installation de PHP 8.2 et extensions nécessaires :\033[0m"
echo -e "  - \033[1;34mphp8.2\033[0m (PHP 8.2)"
echo -e "  - \033[1;34mphp8.2-fpm\033[0m (PHP FastCGI Process Manager)"
echo -e "  - \033[1;34mphp8.2-mbstring\033[0m (pour les chaînes de caractères multi-octets)"
echo -e "  - \033[1;34mphp8.2-xml\033[0m (pour le traitement XML)"
echo -e "  - \033[1;34mphp8.2-zip\033[0m (pour la compression et décompression de fichiers)"
echo -e "  - \033[1;34mphp8.2-bcmath\033[0m (pour les calculs mathématiques de précision)"
echo -e "  - \033[1;34mphp8.2-sqlite3\033[0m (pour utiliser SQLite comme base de données)"
echo -e "  - \033[1;34mphp8.2-mysql\033[0m (pour utiliser MySQL comme base de données)"
echo -e "  - \033[1;34mphp8.2-pgsql\033[0m (pour utiliser PostgreSQL comme base de données)"
echo -e "\033[1;32m- Installation de Composer\033[0m"
echo -e "\033[1;32m- Déploiement d'une application Laravel\033[0m"
echo -e "\033[1;32m- Configuration des permissions pour Laravel\033[0m"
echo -e "\033[1;32m- Génération de la clé Laravel\033[0m"
echo -e "\033[1;32m- Configuration de Nginx pour Laravel\033[0m"
echo -e "\033[1;32m- Configuration de Redis pour écouter uniquement en local\033[0m"
echo -e "\033[1;32m- Configuration de Supervisor pour les workers Laravel\033[0m"
echo -e "\033[1;32m- Redémarrage des services (Nginx, PHP-FPM, Redis, Supervisor)\033[0m"
echo -e "\033[1;32m- Vérification des versions installées\033[0m"

# Demander une confirmation avant de continuer
read -p "Voulez-vous continuer ? (Oui/Non) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Oo]$ ]]; then
    echo -e "\033[1;31m❌ Installation annulée.\033[0m"
    exit 1
fi

echo "📝 Journalisation des étapes..."
exec > >(sudo tee /var/log/vm_setup.log) 2>&1

echo "🔄 Mise à jour des paquets..."
sudo apt update -qq && sudo apt upgrade -y
show_progress 0.5 10  # Barre de progression pendant la mise à jour

echo "📦 Installation des dépendances de base..."
sudo apt install -y software-properties-common curl git unzip supervisor cron redis-server
show_progress 0.5 10  # Barre de progression pendant l'installation

echo "📦 Installation de Node.js et NPM..."
curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
sudo apt install -y nodejs
show_progress 0.5 10  # Barre de progression pendant l'installation

echo "📦 Ajout du dépôt PHP 8.2 et installation..."
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update -qq
sudo apt install -y nginx php8.2 php8.2-fpm php8.2-mbstring php8.2-xml php8.2-zip php8.2-bcmath php8.2-sqlite3 php8.2-mysql php8.2-pgsql
show_progress 0.5 10  # Barre de progression pendant l'installation

echo "📦 Installation de Composer..."
curl -sS https://getcomposer.org/installer | php -- --install-dir=/tmp
sudo mv /tmp/composer.phar /usr/local/bin/composer
show_progress 0.5 5  # Barre de progression pendant l'installation

echo "🚀 Déploiement de Laravel..."
sudo mkdir -p /var/www
cd /var/www

# Supprimer le répertoire laravel s'il existe déjà
if [ -d "laravel" ]; then
    echo "🗑️ Suppression de l'ancien répertoire laravel..."
    sudo rm -rf laravel
fi

export COMPOSER_ALLOW_SUPERUSER=1
yes | composer create-project --prefer-dist laravel/laravel laravel --no-interaction --no-dev
show_progress 0.5 10  # Barre de progression pendant la création du projet

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

echo "🔧 Configuration de Redis pour écouter uniquement en local..."
sudo sed -i 's/bind 127.0.0.1 ::1/bind 127.0.0.1/' /etc/redis/redis.conf
sudo systemctl restart redis-server

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

echo "✅ Vérification des services..."
sudo systemctl is-active --quiet nginx && echo "✅ Nginx est actif" || echo "❌ Nginx n'est pas actif"
sudo systemctl is-active --quiet php8.2-fpm && echo "✅ PHP-FPM est actif" || echo "❌ PHP-FPM n'est pas actif"
sudo systemctl is-active --quiet redis-server && echo "✅ Redis est actif" || echo "❌ Redis n'est pas actif"
sudo systemctl is-active --quiet supervisor && echo "✅ Supervisor est actif" || echo "❌ Supervisor n'est pas actif"

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

echo -e "\n\033[1;32m✅ Déploiement réussi ! Accès : http://$(hostname -I | awk '{print $1}')\033[0m"
