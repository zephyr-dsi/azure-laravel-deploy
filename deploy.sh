# Afficher le lien d'accès à l'application en grand
echo -e "\n\033[1;32m✅ Déploiement réussi !\033[0m"
echo -e "\033[1;36m========================================\033[0m"
echo -e "\033[1;36m🌐 Accédez à votre application Laravel :\033[0m"
echo -e "\033[1;36m========================================\033[0m"
echo -e "\033[1;36m      http://$(hostname -I | awk '{print $1}')\033[0m"
echo -e "\033[1;36m========================================\033[0m"

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

# Résumé des ports à ouvrir sur Azure
echo -e "\n\033[1;33m📋 Résumé des ports à ouvrir sur Azure :\033[0m"
echo -e "+-------+----------------------+-----------------------------------------+"
echo -e "| Port  | Utilisation          | Recommandation                          |"
echo -e "+-------+----------------------+-----------------------------------------+"
echo -e "| \033[1;34m80\033[0m    | HTTP                 | Ouvrir pour l'accès public.             |"
echo -e "| \033[1;34m443\033[0m   | HTTPS                | Ouvrir pour l'accès sécurisé (SSL).     |"
echo -e "| \033[1;34m3306\033[0m  | MySQL                | Restreindre à votre IP ou réseau privé. |"
echo -e "| \033[1;34m6379\033[0m  | Redis                | Restreindre à votre IP ou réseau privé. |"
echo -e "+-------+----------------------+-----------------------------------------+"
