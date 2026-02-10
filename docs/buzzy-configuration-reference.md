# Buzzy 配置项参考（按当前代码整理）

## 1. 应用行为开关（`lib/buzzy.rb`）

### `DISABLE_SESSION_TRANSFER`

- `true`：禁用并隐藏会话转移/分享登录链接能力
- 默认：启用

### `DISABLE_EXPORT_DATA`

- `true`：禁用并隐藏账户导出与用户数据导出
- 对应控制器会返回 `404`

### `HIDE_EMAILS`

- `true`：UI 中隐藏用户邮箱明文展示（不影响真实投递和登录输入）

### `ADMIN_EMAILS`

- 逗号分隔邮箱列表
- 命中后视为超级管理员（可访问全局管理能力）

### `DATABASE_ADAPTER`

- `sqlite`（默认）或 `mysql`
- 决定 `config/database.yml` 最终加载哪份配置

## 2. Forward Auth（`config/initializers/forward_auth.rb`）

- `FORWARD_AUTH_ENABLED`
- `FORWARD_AUTH_TRUSTED_IPS`
- `FORWARD_AUTH_SECRET_HEADER`
- `FORWARD_AUTH_SECRET`
- `FORWARD_AUTH_AUTO_PROVISION`
- `FORWARD_AUTH_DEFAULT_ROLE`
- `FORWARD_AUTH_CREATE_SESSION`
- `FORWARD_AUTH_USE_EMAIL_LOCAL_PART_AND_LOCK_EMAIL`
- `FORWARD_AUTH_AUTO_CREATE_ACCOUNT`
- `FORWARD_AUTH_AUTO_CREATE_ACCOUNT_NAME`

这些配置用于在反向代理已认证前提下，信任请求头并接入 Buzzy 登录态。

## 3. 邮件配置（development/production）

### SMTP

- `SMTP_ADDRESS`（存在即启用 SMTP）
- `SMTP_PORT`
- `SMTP_DOMAIN`
- `SMTP_USERNAME`
- `SMTP_PASSWORD`
- `SMTP_AUTHENTICATION`
- `SMTP_TLS`
- `SMTP_SSL_VERIFY_MODE`

### URL

- `BASE_URL`：生成邮件与外链的默认 host/protocol/port

## 4. 存储配置

### Active Storage 服务选择

- `ACTIVE_STORAGE_SERVICE`（生产默认 `local`）
- 可选值受 `config/storage.oss.yml` 中服务定义约束（如 `local`、`s3`、`devminio`）

### S3 相关

- `S3_ACCESS_KEY_ID`
- `S3_SECRET_ACCESS_KEY`
- `S3_BUCKET`
- `S3_ENDPOINT`
- `S3_FORCE_PATH_STYLE`
- `S3_REGION`
- `S3_REQUEST_CHECKSUM_CALCULATION`
- `S3_RESPONSE_CHECKSUM_VALIDATION`

## 5. 队列与并发

- `SOLID_QUEUE_IN_PUMA`：是否在 Puma 进程内启用 Solid Queue 插件
- `JOB_CONCURRENCY`：`config/queue.yml` 中 worker 进程数
- `WEB_CONCURRENCY`：Puma worker 数（非本地环境）

## 6. SSL 与日志

- `DISABLE_SSL`：全局关闭 SSL 相关默认启用行为
- `ASSUME_SSL`：是否假设由上游终止 SSL
- `FORCE_SSL`：是否强制 HTTPS
- `RAILS_LOG_LEVEL`：日志级别

## 7. `.env.example` 与运行时关系

`buzzy/.env.example` 主要服务于 Docker Compose 的环境变量替换；容器内应用并不是“自动读取 `.env` 文件”，而是读取注入到进程环境中的变量。
