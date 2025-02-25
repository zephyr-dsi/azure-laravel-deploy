runcmd:
  - curl -sSL https://raw.githubusercontent.com/zephyr-dsi/azure-laravel-deploy/main/deploy.sh -o /tmp/deploy.sh
  - chmod +x /tmp/deploy.sh
  - sudo /tmp/deploy.sh


curl -O https://raw.githubusercontent.com/zephyr-dsi/azure-laravel-deploy/main/deploy.sh
chmod +x deploy.sh
sudo ./deploy.sh
