#!/bin/sh
# 每次 db 就绪后执行：将 buzzy 改为 mysql_native_password（数据卷已存在时 initdb 不会跑，故在此补做）
set -e
PASSWORD_ESC=$(echo "$MYSQL_PASSWORD" | sed "s/'/''/g")
mysql -h "${MYSQL_HOST:-db}" -u root -p"$MYSQL_ROOT_PASSWORD" -e "ALTER USER 'buzzy'@'%' IDENTIFIED WITH mysql_native_password BY '$PASSWORD_ESC'; FLUSH PRIVILEGES;"
