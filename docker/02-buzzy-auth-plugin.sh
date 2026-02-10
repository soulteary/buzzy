#!/bin/bash
# 使用 mysql_native_password，以便在无 TLS 的 TCP 上连接（Trilogy 与 caching_sha2_password 不兼容）
set -e
PASSWORD_ESC=$(echo "$MYSQL_PASSWORD" | sed "s/'/''/g")
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "ALTER USER 'buzzy'@'%' IDENTIFIED WITH mysql_native_password BY '$PASSWORD_ESC'; FLUSH PRIVILEGES;"
