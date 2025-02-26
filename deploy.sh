#!/bin/bash
set -euo pipefail
exec > >(tee -a /var/log/deploy_laravel_debug.log) 2>&1
set -x  # Affiche chaque commande exécutée

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
print_title "🛠️ Script de déploiement d'une application Laravel sur Azure V 5.0 🚀"

# Confirmation utilisateur
read -p "Voulez-vous continuer ? (Oui/Non) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Oo]$ ]]; then
    echo -e "\033[1;31m❌ Installation annulée.\033[0m"
    exit 1
fi

# Mise à jour des paquets
echo "🔄 Mise à jour des paquets..."
sudo apt update -qq && sudo apt upgrade -y
show_progress 0.5 10

# Installation des dépendances de base
echo "📦 Installation des dépendances de base..."
sudo apt install -y software-properties-common curl git unzip supervisor cron redis-server
show_progress 0.5 10

# Installation de Node.js 20 LTS et NPM
echo "📦 Installation de Node.js 20 LTS et NPM..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
show_progress 0.5 10

# Installation de PHP 8.2 et extensions
echo "📦 Installation de PHP 8.2 et extensions..."
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update -qq
sudo apt install -y nginx php8.2 php8.2-fpm php8.2-mbstring php8.2-xml php8.2-zip php8.2-bcmath php8.2-sqlite3 php8.2-mysql php8.2-pgsql php8.2-curl php8.2-gd php8.2-intl php8.2-readline php8.2-tokenizer php8.2-opcache php8.2-redis php8.2-memcached
show_progress 0.5 10

# Installation de Composer
echo "📦 Installation de Composer..."
curl -sS https://getcomposer.org/installer | php -- --install-dir=/tmp
sudo mv /tmp/composer.phar /usr/local/bin/composer

# Vérification de l'installation de Composer
if ! command -v composer &> /dev/null; then
    echo "❌ Composer n'est pas installé correctement."
    exit 1
fi
show_progress 0.5 5

# Déploiement de Laravel
echo "🚀 Déploiement de Laravel..."
sudo mkdir -p /var/www
cd /var/www

# Suppression du dossier Laravel existant
if [ -d "laravel" ]; then
    echo "🗑️ Suppression de l'ancien répertoire Laravel..."
    sudo rm -rf laravel
fi

export COMPOSER_ALLOW_SUPERUSER=1
yes | composer create-project --prefer-dist laravel/laravel laravel --no-interaction --no-dev
show_progress 0.5 10

if [ ! -d "/var/www/laravel" ]; then
    echo "❌ Échec de l'installation de Laravel."
    exit 1
fi

# Configuration des permissions Laravel
echo "🔧 Configuration des permissions pour Laravel..."
sudo chown -R www-data:www-data /var/www/laravel
sudo chmod -R 775 /var/www/laravel/storage /var/www/laravel/bootstrap/cache
sudo chmod -R 775 /var/www/laravel/storage/framework/views
sudo chmod -R 775 /var/www/laravel/storage/logs
sudo chmod -R 775 /var/www/laravel/bootstrap/cache

# Génération de la clé Laravel et cache
echo "🔑 Configuration de Laravel..."
cd /var/www/laravel
yes | php artisan key:generate --force
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan storage:link  # Crée le lien symbolique pour le stockage

# Configuration de Nginx
echo "🔧 Configuration de Nginx..."
sudo tee /etc/nginx/sites-available/laravel > /dev/null <<'EOF'
server {
    listen 80;
    server_name _;
    root /var/www/laravel/public;
    index index.php index.html index.htm;
    server_tokens off;

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

    # En-têtes de sécurité
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
    add_header X-XSS-Protection "1; mode=block";
}
EOF

# Activation et test de la configuration Nginx
sudo ln -sf /etc/nginx/sites-available/laravel /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx

# Configuration de Redis
echo "🔧 Configuration de Redis..."
sudo sed -i 's/bind 127.0.0.1 ::1/bind 127.0.0.1/' /etc/redis/redis.conf
sudo systemctl restart redis-server

# Configuration de Supervisor
echo "🔧 Configuration de Supervisor..."
sudo tee /etc/supervisor/conf.d/laravel-worker.conf > /dev/null <<'EOF'
[program:laravel-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/laravel/artisan queue:work --sleep=3 --tries=3
autostart=true
autorestart=true
user=www-data
numprocs=2
redirect_stderr=true
stdout_logfile=/var/www/laravel/storage/logs/worker.log
EOF

# Redémarrage des services
echo "🔧 Redémarrage des services..."
SERVICES=("nginx" "php8.2-fpm" "supervisor" "cron" "redis-server")
for service in "${SERVICES[@]}"; do
    echo "🔄 Redémarrage de $service..."
    if sudo systemctl restart "$service"; then
        echo "✅ $service redémarré avec succès."
    else
        echo "❌ Échec du redémarrage de $service. Affichage des logs :"
        sudo journalctl -xe -u "$service"
        exit 1
    fi
done

# Activation des services au démarrage
echo "🔧 Activation des services au démarrage..."
for service in "${SERVICES[@]}"; do
    sudo systemctl enable "$service"
    echo "✅ $service activé au démarrage."
done

# Vérification des services
echo "✅ Vérification des services..."
for service in "${SERVICES[@]}"; do
    if sudo systemctl is-active --quiet "$service"; then
        echo "✅ $service est actif"
    else
        echo "❌ $service n'est pas actif"
    fi
done

# Affichage des versions installées
echo -e "\n📋 Versions installées :"
php -v | grep "PHP"
composer --version
node -v
npm -v
nginx -v 2>&1
redis-server --version
supervisord -v

# Affichage des liens d'accès
IP_PRIVATE=$(hostname -I | xargs | awk '{print $1}')
IP_PUBLIC=$(curl -s ifconfig.me)
echo -e "\n🌐 Accédez à votre application Laravel :"
echo -e "🛡️  IP Privée  : http://$IP_PRIVATE"
echo -e "🌍 IP Publique : http://$IP_PUBLIC"

# Afficher les ports à ouvrir sur Azure
echo -e "\n\033[1;33m🔒 Ports à ouvrir sur Azure :\033[0m"
echo -e "  - \033[1;34m80 (HTTP)\033[0m : Pour accéder à l'application via HTTP."
echo -e "  - \033[1;34m443 (HTTPS)\033[0m : Pour accéder à l'application via HTTPS (si vous configurez SSL)."
echo -e "  - \033[1;34m3306 (MySQL)\033[0m : Pour permettre l'accès à la base de données MySQL (si utilisé)."
echo -e "  - \033[1;34m6379 (Redis)\033[0m : Pour permettre l'accès à Redis (si utilisé)."

# Suggestions supplémentaires
echo -e "\n\033[1;33m💡 Suggestions supplémentaires :\033[0m"
echo -e "  - \033[1;34mConfigurer un pare-feu avec Azure NSG :\033[0m"
echo -e "    - Utilisez Azure NSG (Network Security Group) pour restreindre l'accès aux ports nécessaires."
echo -e "    - Par exemple :"
echo -e "      - Autorisez uniquement le port \033[1;34m80 (HTTP)\033[0m et \033[1;34m443 (HTTPS)\033[0m pour l'accès public."
echo -e "      - Restreignez l'accès au port \033[1;34m3306 (MySQL)\033[0m et \033[1;34m6379 (Redis)\033[0m à votre adresse IP ou à un réseau privé."
echo -e "  - \033[1;34mConfigurer un système de logs centralisé :\033[0m"
echo -e "    - Utilisez \033[1;34mLogstash\033[0m ou \033[1;34mFluentd\033[0m pour centraliser les logs de votre application."
echo -e "    - Configurez Laravel pour envoyer les logs vers un service externe comme \033[1;34mPapertrail\033[0m ou \033[1;34mLoggly\033[0m."
echo -e "  - \033[1;34mMettre en place un système de monitoring :\033[0m"
echo -e "    - Utilisez \033[1;34mNew Relic\033[0m ou \033[1;34mDatadog\033[0m pour surveiller les performances de votre application en temps réel."

echo -e "\n✅ Déploiement réussi ! 🎉"
