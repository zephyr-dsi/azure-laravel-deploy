#cloud-config
package_update: true
runcmd:
  - curl -sSL https://raw.githubusercontent.com/zephyr-dsi/azure-laravel-deploy/main/deploy.sh -o /tmp/deploy.sh
  - chmod +x /tmp/deploy.sh
  - /tmp/deploy.sh
  - sudo /tmp/deploy.sh

