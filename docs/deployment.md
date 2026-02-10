# 部署说明

本文档说明使用 **Docker** 或 **Kamal** 部署 Buzzy 的方式。二者共用部分环境变量，下面先列出通用配置，再分述两种部署。

---

## 通用环境变量

以下变量在 Docker 与 Kamal 中均会用到：

| 变量 | 说明 |
|------|------|
| `SECRET_KEY_BASE` | 长随机密钥，用于加密等；可用 `bin/rails secret` 生成。运行时必须与生成内容时一致，否则 Action Text 的 @mention 等会解析失败并显示为「未知用户」。 |
| `BASE_URL` | 实例对外访问地址（如 `https://buzzy.example.com`），用于邮件链接等 |
| `MAILER_FROM_ADDRESS` | 发件人地址 |
| `SMTP_ADDRESS` / `SMTP_PORT` / `SMTP_USERNAME` / `SMTP_PASSWORD` | SMTP 配置；可选 `SMTP_TLS`、`SMTP_DOMAIN`、`SMTP_AUTHENTICATION`、`SMTP_SSL_VERIFY_MODE`，见 [Rails Action Mailer](https://guides.rubyonrails.org/action_mailer_basics.html#action-mailer-configuration) |
| `VAPID_PRIVATE_KEY` / `VAPID_PUBLIC_KEY` | Web Push 通知密钥对；在控制台执行 `WebPush.generate_key` 后填入 |
| `MULTI_TENANT` | 默认单账户；设为 `true` 允许多账户注册 |
| `ACTIVE_STORAGE_SERVICE` | 默认本地存储；设为 `s3` 时需配置 `S3_BUCKET`、`S3_REGION`、`S3_ACCESS_KEY_ID`、`S3_SECRET_ACCESS_KEY`，可选 `S3_ENDPOINT`、`S3_FORCE_PATH_STYLE` 等 |

---

## 一、Docker 部署

适用于不修改源码、直接使用现成镜像的场景。镜像示例：`ghcr.io/basecamp/buzzy:main`。

### 存储卷

应用数据默认在容器内 `/rails/storage`，需挂载持久卷，例如：

```sh
docker run --volume buzzy:/rails/storage ghcr.io/basecamp/buzzy:main
```

### SSL 与端口

- 需应用自身处理 SSL：设置 `TLS_DOMAIN=buzzy.example.com`，并映射 80/443。
- 若由前置代理终止 SSL：只映射 80，不设 `TLS_DOMAIN`。
- 本地或禁用 SSL：设置 `DISABLE_SSL=true`。

示例：

```sh
docker run --publish 80:80 --publish 443:443 --env TLS_DOMAIN=buzzy.example.com --env SECRET_KEY_BASE=... ...
```

### docker-compose 示例

```yaml
services:
  web:
    image: ghcr.io/basecamp/buzzy:main
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    environment:
      - SECRET_KEY_BASE=abcdefabcdef
      - TLS_DOMAIN=buzzy.example.com
      - BASE_URL=https://buzzy.example.com
      - MAILER_FROM_ADDRESS=buzzy@example.com
      - SMTP_ADDRESS=mail.example.com
      - SMTP_USERNAME=user
      - SMTP_PASSWORD=pass
      - VAPID_PRIVATE_KEY=myvapidprivatekey
      - VAPID_PUBLIC_KEY=myvapidpublickey
    volumes:
      - buzzy:/rails/storage

volumes:
  buzzy:
```

### 故障排查：SQLite 报错 "database disk image is malformed"

多为卷内 SQLite 文件损坏（异常断电、杀进程、网络盘/绑定挂载等）。处理步骤：

1. 停止应用，备份存储目录（如 `cp -a buzzy_storage buzzy_storage.bak`）。
2. 删除损坏的库文件（常见为 `production_queue.sqlite3`，若主库也报错则一并处理）。
3. 重新启动；entrypoint 会执行 `db:prepare`。必要时执行 `docker compose exec app bin/rails db:migrate:queue` 或 `db:create db:migrate`。
4. 生产环境建议使用 **MySQL**（`DATABASE_ADAPTER=mysql` 及对应 db 服务）以降低此类风险。

---

## 二、Kamal 部署

适用于需要改代码并部署到自有服务器的场景。[Kamal](https://kamal-deploy.org/) 负责在裸机上安装 Docker、构建镜像并管理配置。

### 步骤概要

1. Fork 仓库，本地执行 `bin/setup`。
2. 运行 `kamal init` 生成 `.kamal` 及 `.kamal/secrets`。
3. 编辑 `config/deploy.yml` 中「About your deployment」：`servers/web`、`ssh/user`、`proxy/ssl` 与 `proxy/host`、`env/clear/BASE_URL`、`env/clear/MAILER_FROM_ADDRESS`、`env/clear/SMTP_ADDRESS`、`env/clear/MULTI_TENANT` 等。
4. 在 `.kamal/secrets` 中配置敏感项（**不要提交到仓库**），例如：

   ```ini
   SECRET_KEY_BASE=12345
   VAPID_PUBLIC_KEY=...
   VAPID_PRIVATE_KEY=...
   SMTP_USERNAME=...
   SMTP_PASSWORD=...
   ```

5. 首次部署：`bin/kamal setup`；之后更新：`bin/kamal deploy`。

### 文件存储（Active Storage）

生产默认使用本地磁盘。若使用 S3，设置 `ACTIVE_STORAGE_SERVICE=s3` 及 `S3_ACCESS_KEY_ID`、`S3_BUCKET`、`S3_REGION`、`S3_SECRET_ACCESS_KEY`；S3 兼容端点可配 `S3_ENDPOINT`、`S3_FORCE_PATH_STYLE` 等。

更多 Kamal 用法见 [Kamal 文档](https://kamal-deploy.org/docs/configuration/environment-variables/#secrets)。
