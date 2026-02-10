# Buzzy 开发指南（基于当前实现）

## 1. 目录与入口

- 应用目录：`buzzy/`
- 默认开发入口：`buzzy/bin/dev`
- 初始化脚本：`buzzy/bin/setup`

默认本地访问地址为：

- `http://buzzy.localhost:3006`

`bin/dev` 会输出默认登录邮箱提示（`david@example.com`）。

## 2. 环境准备流程

`buzzy/bin/setup` 的实际流程：

1. 安装或检查 `gum`、`mise`、`gh`
2. 通过 `mise install` 安装 Ruby 工具链
3. 安装系统依赖（brew 或 pacman）
4. `bundle install`
5. 数据库准备（`db:prepare`；`--reset` 时 `db:reset`）
6. 视数据状态决定是否自动 `db:seed`
7. 清理日志与临时文件

当 `DATABASE_ADAPTER=mysql` 时，脚本会尝试自动拉起本地 Docker MySQL（容器名 `buzzy-mysql`）。

## 3. 开发启动行为

`buzzy/bin/dev` 当前包含以下行为：

- 默认端口 `3006`
- 若不存在 `tmp/solid-queue.txt`，自动设置 `SOLID_QUEUE_IN_PUMA=false`
- 若存在 `tmp/oss-config.txt`，设置 `OSS_CONFIG=1`
- 支持 `--tailscale`，自动配置 `tailscale serve` 反向代理
- 最终执行：`./bin/rails server -b 0.0.0.0 -p 3006`

## 4. 数据库模式与切换

数据库选择由 `Buzzy.db_adapter` 决定：

- 默认：`sqlite`
- 可选：`mysql`

关键配置文件：

- `buzzy/config/database.yml`（分发入口）
- `buzzy/config/database.sqlite.yml`
- `buzzy/config/database.mysql.yml`

建议实践：

- 本地快速开发优先 SQLite
- 关注 MySQL 兼容性或生产近似行为时切换 MySQL

## 5. 存储与邮件（开发态）

### Active Storage

- 默认本地磁盘：`local`
- 可切换 MinIO：创建 `tmp/minio-dev.txt` 后使用 `devminio`

### 邮件发送

开发环境策略（`buzzy/config/environments/development.rb`）：

1. 若配置 `SMTP_ADDRESS`，使用 SMTP
2. 否则若存在 `tmp/email-dev.txt`，使用 `letter_opener`
3. 否则使用 `:test` delivery，不真实发送

## 6. 常用命令

在 `buzzy/` 目录执行：

- `bin/setup`：首次初始化
- `bin/dev`：启动开发服务
- `bin/rails test`：运行测试
- `bin/rails test:system`：系统测试
- `bin/ci`：完整 CI 检查
- `bin/jobs`：Solid Queue CLI

## 7. 关键环境变量（开发常用）

### 基础运行

- `DATABASE_ADAPTER`：`sqlite` / `mysql`
- `BASE_URL`：邮件中 URL 生成基地址
- `RAILS_LOG_LEVEL`

### 登录与安全

- `ADMIN_EMAILS`：超级管理员邮箱列表（逗号分隔）
- `DISABLE_SESSION_TRANSFER`：关闭会话转移链接
- `DISABLE_EXPORT_DATA`：关闭导出能力
- `HIDE_EMAILS`：UI 脱敏显示邮箱

### Forward Auth（可选）

- `FORWARD_AUTH_ENABLED`
- `FORWARD_AUTH_TRUSTED_IPS`
- `FORWARD_AUTH_SECRET_HEADER`
- `FORWARD_AUTH_SECRET`
- `FORWARD_AUTH_AUTO_PROVISION`
- `FORWARD_AUTH_DEFAULT_ROLE`
- `FORWARD_AUTH_CREATE_SESSION`

参考：`buzzy/.env.example` 与 `buzzy/config/initializers/forward_auth.rb`
