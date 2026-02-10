#!/bin/bash
# Buzzy production 所需数据库（与 app 的 config/database.mysql.yml 一致）
# 授权给 MYSQL_USER，与 docker-compose 中 db 的 MYSQL_USER 一致，app 的 MYSQL_USER 须与之相同
set -e
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" <<EOSQL
CREATE DATABASE IF NOT EXISTS buzzy_production CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS buzzy_production_cable CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS buzzy_production_queue CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS buzzy_production_cache CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON buzzy_production.* TO '${MYSQL_USER}'@'%';
GRANT ALL PRIVILEGES ON buzzy_production_cable.* TO '${MYSQL_USER}'@'%';
GRANT ALL PRIVILEGES ON buzzy_production_queue.* TO '${MYSQL_USER}'@'%';
GRANT ALL PRIVILEGES ON buzzy_production_cache.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOSQL
