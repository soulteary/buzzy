# Buzzy 异步任务与运维说明

## 1. 队列与执行模型

当前实现使用：

- Active Job + `solid_queue`
- Action Cable + `solid_cable`
- 缓存 + `solid_cache`

关键配置：

- `buzzy/config/queue.yml`
- `buzzy/config/cable.yml`
- `buzzy/config/environments/production.rb`

## 2. Job 的租户上下文传递

实现文件：`buzzy/config/initializers/active_job.rb`

设计要点：

- Job 入队时序列化 `Current.account`（GlobalID）
- Job 执行时恢复 account 上下文
- 避免多租户任务执行错租户
- 对 Active Storage variant 任务做了额外异常容错，减少跨账户附件场景下的失败噪音

## 3. 主要 Job 列表（app/jobs）

- `account/data_import_job.rb`
- `account/incinerate_due_job.rb`
- `board/clean_inaccessible_data_job.rb`
- `card/activity_spike/detection_job.rb`
- `card/clean_inaccessible_data_job.rb`
- `card/remove_inaccessible_notifications_job.rb`
- `data_export_job.rb`
- `delete_unused_tags_job.rb`
- `event/webhook_dispatch_job.rb`
- `mention/create_job.rb`
- `notification/bundle/deliver_job.rb`
- `notification/bundle/deliver_all_job.rb`
- `notify_recipients_job.rb`
- `push_notification_job.rb`
- `storage/materialize_job.rb`
- `storage/reconcile_job.rb`
- `webhook/delivery_job.rb`

## 4. 定时任务（Recurring）

配置文件：`buzzy/config/recurring.yml`

当前生产组任务包括：

- 通知聚合分发（每分钟）
- 自动延后到期卡片（每小时）
- 清理未使用标签（每日）
- 清理已完成 Solid Queue 任务（每小时）
- 清理 webhook 投递记录（每 4 小时）
- 清理 magic link（每 4 小时）
- 清理导入导出产物（每小时）
- 账户到期焚毁（每 8 小时）

## 5. Puma 与队列协同

配置文件：`buzzy/config/puma.rb`

- 默认可在 Puma 中启用 `plugin :solid_queue`
- 设置 `SOLID_QUEUE_IN_PUMA=false` 可禁用
- 本地开发脚本 `bin/dev` 默认会在缺少 `tmp/solid-queue.txt` 时禁用该插件

## 6. 运维相关入口

- `bin/ci`：完整检查流水（style/security/tests）
- `bin/brakeman`、`bin/bundler-audit`、`bin/gitleaks-audit`：安全检查
- `bin/jobs`：队列 CLI
- `admin/jobs`：Mission Control Jobs 可视化后台

## 7. 生产环境关键关注点

- 通过 `BASE_URL` 配置外链域名，确保邮件中的 URL 正确
- SMTP 未配置时生产默认不投递邮件（避免连接本机 25 端口报错）
- SSL 行为由 `DISABLE_SSL` / `ASSUME_SSL` / `FORCE_SSL` 协同决定
- Active Storage 默认 `local`，可通过 `ACTIVE_STORAGE_SERVICE` 切换至 `s3`
