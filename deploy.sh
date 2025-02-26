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
command -v composer || { echo "❌ Composer n'est pas installé."; exit 1; }
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

# Vérification des permissions
ls -lah /var/www/laravel/storage
ls -lah /var/www/laravel/bootstrap/cache

# Génération de la clé Laravel et cache
echo "🔑 Configuration de Laravel..."
cd /var/www/laravel
php artisan key:generate --force || { echo "❌ Échec de la génération de la clé."; exit 1; }
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan storage:link

# 🚨 Vérification avant migration
echo "🔎 Vérification de la base de données..."
cat .env | grep DB_

# 🚨 Test de connexion à la base de données
echo "🔄 Test de connexion MySQL..."
mysqladmin ping -h 127.0.0.1 || { echo "❌ Impossible de se connecter à MySQL."; exit 1; }

# 🔄 Migration avec timeout et debug
echo "🔄 Exécution des migrations Laravel..."
timeout 60s php artisan migrate --force --no-interaction || { echo "❌ Échec des migrations."; exit 1; }

# 🔎 Vérification si migration bien passée
echo "✅ Migrations terminées, passage à la suite..."
sleep 2
ls -lah storage/logs/

# Configuration de Nginx
echo "🔧 Configuration de Nginx..."
sudo tee /etc/nginx/sites-available/laravel > /dev/null <<'EOF'
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
}
EOF

# Activation et test de la configuration Nginx
sudo ln -sf /etc/nginx/sites-available/laravel /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx

# Redémarrage des services
echo "🔧 Redémarrage des services..."
for service in nginx php8.2-fpm supervisor cron redis-server; do
    echo "🔄 Redémarrage de $service..."
    sudo systemctl restart "$service" || { echo "❌ Échec du redémarrage de $service."; exit 1; }
done

# Vérification des services
echo "✅ Vérification des services..."
for service in nginx php8.2-fpm supervisor cron redis-server; do
    sudo systemctl is-active --quiet "$service" && echo "✅ $service est actif" || echo "❌ $service est inactif"
done

# Affichage des liens d'accès
IP_PRIVATE=$(hostname -I | xargs | awk '{print $1}')
IP_PUBLIC=$(curl -s ifconfig.me)
echo -e "\n🌐 Accédez à votre application Laravel :"
echo -e "🛡️  IP Privée  : http://$IP_PRIVATE"
echo -e "🌍 IP Publique : http://$IP_PUBLIC"

echo -e "\n✅ Déploiement réussi ! 🎉"
