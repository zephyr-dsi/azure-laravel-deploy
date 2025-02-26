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

# Fonction pour exécuter des commandes avec gestion d'erreurs
function run_command {
    local command="$1"
    local description="$2"

    echo "🚀 Exécution : $description"
    $command 2>> /var/log/laravel_errors.log
    if [ $? -ne 0 ]; then
        echo "⚠️ Erreur lors de l'exécution de : $description"
        echo "🔍 Voir /var/log/laravel_errors.log pour plus de détails."
        return 1
    else
        echo "✅ Succès : $description"
        return 0
    fi
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
run_command "sudo apt update -qq" "Mise à jour des paquets" || { echo "❌ Échec de la mise à jour des paquets."; exit 1; }
run_command "sudo apt upgrade -y" "Mise à niveau des paquets" || { echo "❌ Échec de la mise à niveau des paquets."; exit 1; }
show_progress 0.5 10

# Installation des dépendances de base
echo "📦 Installation des dépendances de base..."
run_command "sudo apt install -y software-properties-common curl git unzip supervisor cron redis-server" "Installation des dépendances de base" || { echo "❌ Échec de l'installation des dépendances de base."; exit 1; }
show_progress 0.5 10

# Installation de Node.js 20 LTS et NPM
echo "📦 Installation de Node.js 20 LTS et NPM..."
run_command "curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -" "Configuration de Node.js" || { echo "❌ Échec de la configuration de Node.js."; exit 1; }
run_command "sudo apt install -y nodejs" "Installation de Node.js" || { echo "❌ Échec de l'installation de Node.js."; exit 1; }
show_progress 0.5 10

# Installation de PHP 8.2 et extensions
echo "📦 Installation de PHP 8.2 et extensions..."
run_command "sudo add-apt-repository ppa:ondrej/php -y" "Ajout du dépôt PHP" || { echo "❌ Échec de l'ajout du dépôt PHP."; exit 1; }
run_command "sudo apt update -qq" "Mise à jour des paquets" || { echo "❌ Échec de la mise à jour des paquets."; exit 1; }
run_command "sudo apt install -y nginx php8.2 php8.2-fpm php8.2-mbstring php8.2-xml php8.2-zip php8.2-bcmath php8.2-sqlite3 php8.2-mysql php8.2-pgsql php8.2-curl php8.2-gd php8.2-intl php8.2-readline php8.2-tokenizer php8.2-opcache php8.2-redis php8.2-memcached" "Installation de PHP et extensions" || { echo "❌ Échec de l'installation de PHP et extensions."; exit 1; }
show_progress 0.5 10

# Installation de Composer
echo "📦 Installation de Composer..."
run_command "curl -sS https://getcomposer.org/installer | php -- --install-dir=/tmp" "Téléchargement de Composer" || { echo "❌ Échec du téléchargement de Composer."; exit 1; }
run_command "sudo mv /tmp/composer.phar /usr/local/bin/composer" "Installation de Composer" || { echo "❌ Échec de l'installation de Composer."; exit 1; }

# Vérification de l'installation de Composer
if ! command -v composer &> /dev/null; then
    echo "❌ Composer n'est pas installé correctement."
    exit 1
fi
show_progress 0.5 5

# Déploiement de Laravel
echo "🚀 Déploiement de Laravel..."
run_command "sudo mkdir -p /var/www" "Création du répertoire /var/www" || { echo "❌ Échec de la création du répertoire /var/www."; exit 1; }
cd /var/www

# Suppression du dossier Laravel existant
if [ -d "laravel" ]; then
    echo "🗑️ Suppression de l'ancien répertoire Laravel..."
    run_command "sudo rm -rf laravel" "Suppression de l'ancien répertoire Laravel" || { echo "❌ Échec de la suppression de l'ancien répertoire Laravel."; exit 1; }
fi

export COMPOSER_ALLOW_SUPERUSER=1
run_command "yes | composer create-project --prefer-dist laravel/laravel laravel --no-interaction --no-dev" "Création du projet Laravel" || { echo "❌ Échec de la création du projet Laravel."; exit 1; }
show_progress 0.5 10

if [ ! -d "/var/www/laravel" ]; then
    echo "❌ Échec de l'installation de Laravel."
    exit 1
fi

# Configuration des permissions Laravel
echo "🔧 Configuration des permissions pour Laravel..."
run_command "sudo chown -R www-data:www-data /var/www/laravel" "Changement de propriétaire pour Laravel" || { echo "❌ Échec du changement de propriétaire pour Laravel."; exit 1; }
run_command "sudo chmod -R 775 /var/www/laravel/storage /var/www/laravel/bootstrap/cache" "Configuration des permissions pour Laravel" || { echo "❌ Échec de la configuration des permissions pour Laravel."; exit 1; }

# Génération de la clé Laravel et cache
echo "🔑 Configuration de Laravel..."
cd /var/www/laravel
run_command "yes | php artisan key:generate --force" "Génération de la clé Laravel" || { echo "❌ Échec de la génération de la clé Laravel."; exit 1; }
run_command "php artisan config:cache" "Mise en cache de la configuration" || { echo "❌ Échec de la mise en cache de la configuration."; exit 1; }
run_command "php artisan route:cache" "Mise en cache des routes" || { echo "❌ Échec de la mise en cache des routes."; exit 1; }
run_command "php artisan view:cache" "Mise en cache des vues" || { echo "❌ Échec de la mise en cache des vues."; exit 1; }
run_command "php artisan storage:link" "Création du lien symbolique pour le stockage" || { echo "❌ Échec de la création du lien symbolique pour le stockage."; exit 1; }

# Configuration de Nginx
echo "🔧 Configuration de Nginx..."
run_command "sudo tee /etc/nginx/sites-available/laravel > /dev/null <<'EOF'
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
    add_header X-Frame-Options \"SAMEORIGIN\";
    add_header X-Content-Type-Options \"nosniff\";
    add_header X-XSS-Protection \"1; mode=block\";
}
EOF" "Configuration de Nginx" || { echo "❌ Échec de la configuration de Nginx."; exit 1; }

# Activation et test de la configuration Nginx
run_command "sudo ln -sf /etc/nginx/sites-available/laravel /etc/nginx/sites-enabled/" "Activation de la configuration Nginx" || { echo "❌ Échec de l'activation de la configuration Nginx."; exit 1; }
run_command "sudo rm -f /etc/nginx/sites-enabled/default" "Suppression de la configuration par défaut de Nginx" || { echo "❌ Échec de la suppression de la configuration par défaut de Nginx."; exit 1; }
run_command "sudo nginx -t && sudo systemctl reload nginx" "Test et rechargement de Nginx" || { echo "❌ Échec du test ou du rechargement de Nginx."; exit 1; }

# Configuration de Redis
echo "🔧 Configuration de Redis..."
run_command "sudo sed -i 's/bind 127.0.0.1 ::1/bind 127.0.0.1/' /etc/redis/redis.conf" "Configuration de Redis" || { echo "❌ Échec de la configuration de Redis."; exit 1; }
run_command "sudo systemctl restart redis-server" "Redémarrage de Redis" || { echo "❌ Échec du redémarrage de Redis."; exit 1; }

# Configuration de Supervisor
echo "🔧 Configuration de Supervisor..."
run_command "sudo tee /etc/supervisor/conf.d/laravel-worker.conf > /dev/null <<'EOF'
[program:laravel-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/laravel/artisan queue:work --sleep=3 --tries=3
autostart=true
autorestart=true
user=www-data
numprocs=2
redirect_stderr=true
stdout_logfile=/var/www/laravel/storage/logs/worker.log
EOF" "Configuration de Supervisor" || { echo "❌ Échec de la configuration de Supervisor."; exit 1; }

# Redémarrage des services
echo "🔧 Redémarrage des services..."
SERVICES=("nginx" "php8.2-fpm" "supervisor" "cron" "redis-server")
for service in "${SERVICES[@]}"; do
    run_command "sudo systemctl restart $service" "Redémarrage de $service" || { echo "❌ Échec du redémarrage de $service."; exit 1; }
done

# Activation des services au démarrage
echo "🔧 Activation des services au démarrage..."
for service in "${SERVICES[@]}"; do
    run_command "sudo systemctl enable $service" "Activation de $service au démarrage" || { echo "❌ Échec de l'activation de $service au démarrage."; exit 1; }
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
