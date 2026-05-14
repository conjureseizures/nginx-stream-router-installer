#!/bin/bash

set -e

echo "=== NGINX Stream Router Installer ==="

read -p "Введите SNI домен: " SNI_DOMAIN
read -p "Введите внешний порт: " EXTERNAL_PORT
read -p "Введите IP назначения: " DEST_IP
read -p "Введите порт назначения: " DEST_PORT

echo ""
echo "=== Обновление пакетов ==="
sudo apt update && sudo apt upgrade -y

echo ""
echo "=== Установка nginx ==="
sudo apt install nginx -y

echo ""
echo "=== Установка stream module ==="
sudo apt install libnginx-mod-stream -y

echo ""
echo "=== Создание конфигурации nginx ==="

sudo tee /etc/nginx/nginx.conf > /dev/null <<EOF
load_module /usr/lib/nginx/modules/ngx_stream_module.so;

user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

stream {

    log_format stream_log '\$remote_addr [\$time_local] SNI: \$ssl_preread_server_name -> \$upstream_addr \$bytes_sent/\$bytes_received "\$session_time"';

    access_log /var/log/nginx/stream-access.log stream_log;
    error_log  /var/log/nginx/stream-error.log warn;

    map \$ssl_preread_server_name \$backend {
        ${SNI_DOMAIN} foreign;
        default foreign;
    }

    upstream foreign {
        server ${DEST_IP}:${DEST_PORT};
    }

    server {
        listen ${EXTERNAL_PORT} reuseport;
        listen [::]:${EXTERNAL_PORT} reuseport ipv6only=on;

        ssl_preread on;

        proxy_pass \$backend;

        # proxy_protocol on;

        proxy_connect_timeout 10s;
        proxy_timeout 15m;
    }
}
EOF

echo ""
echo "=== Проверка nginx ==="
sudo nginx -t

echo ""
echo "=== Перезапуск nginx ==="
sudo systemctl restart nginx

echo ""
echo "=== Статус nginx ==="
sudo systemctl status nginx --no-pager

echo ""
echo "=== Последние логи ==="
sudo tail -n 50 /var/log/nginx/stream-access.log

echo ""
echo "=== Готово ==="