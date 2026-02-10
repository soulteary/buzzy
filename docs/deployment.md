# Buzzy 部署说明（当前仓库）

## 1. 部署方式概览

当前仓库可用的部署路线：

- Docker / Docker Compose（适合快速自托管）
- Kamal（适合可维护的长期部署）

可执行入口：

- `buzzy/bin/docker-entrypoint`
- `buzzy/bin/kamal`

上游参考文档：

- `fizzy/docs/docker-deployment.md`
- `fizzy/docs/kamal-deployment.md`

## 2. 生产环境关键配置

容器化部署（镜像内不携带 `config/master.key`）时，至少保证以下之一通过环境变量提供：

- `RAILS_MASTER_KEY`
- `SECRET_KEY_BASE`

非容器部署场景下，若主机已提供可用的 `config/master.key`，则不必强制通过环境变量设置上述两项。

常用配套配置：

- `BASE_URL`（邮件链接与外部 URL）
- SMTP 变量（如需真实邮件投递）
- 数据库变量（`DATABASE_ADAPTER`、MySQL 连接参数）
- `ACTIVE_STORAGE_SERVICE`（`local` 或 `s3`）

参考示例：`buzzy/.env.example`

## 3. 数据库与存储决策

### 数据库

- 默认支持 SQLite（部署简单）
- 也支持 MySQL（更适合高并发和复杂查询场景）

### 文件存储

- 可用本地磁盘（`local`）
- 可用 S3 / MinIO（`s3` / `devminio`）

## 4. 队列与后台任务

生产环境默认使用：

- `solid_queue` 作为 Active Job 队列后端
- `config/recurring.yml` 定义周期任务

是否在 Puma 内启用队列插件可通过 `SOLID_QUEUE_IN_PUMA` 控制。

## 5. 运维与可观测性

- 任务后台：`/admin/jobs`（Mission Control Jobs）
- 健康检查：`/up`
- 日志级别：`RAILS_LOG_LEVEL`
- SSL 策略：`DISABLE_SSL` / `ASSUME_SSL` / `FORCE_SSL`

## 6. 部署前检查建议

建议先在 `buzzy/` 执行：

```bash
bin/ci
```

确保风格检查、安全扫描、测试与系统测试通过后再部署。
