#!/bin/bash
# 为当前 MYSQL_USER 授予 production/cable/queue/cache 库权限。
# 使用场景：修改 .env 中 MYSQL_USER 后，或首次初始化时未执行 01-buzzy-databases.sh。
# 从项目根目录执行（compose 会把 .env 中的 MYSQL_USER/MYSQL_ROOT_PASSWORD 注入 db 容器）：
#   docker compose -f docker-compose.mysql.yml exec db bash -s < docker/fix-database-grants.sh
set -e
: "${MYSQL_USER:?set MYSQL_USER}"
: "${MYSQL_ROOT_PASSWORD:?set MYSQL_ROOT_PASSWORD}"
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
echo "Done: granted ${MYSQL_USER} access to buzzy_production, buzzy_production_cable, buzzy_production_queue, buzzy_production_cache."
