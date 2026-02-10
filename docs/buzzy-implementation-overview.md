# Buzzy 实现总览（基于当前代码）

## 1. 项目定位

Buzzy 是 Fizzy 的分支实现，定位为看板式协作与任务跟踪系统。当前仓库由两部分组成：

- `buzzy/`：当前实际运行与维护的应用代码
- `fizzy/`：上游/参考实现（包含部分原始文档）

本文仅描述 `buzzy/` 的现状。

## 2. 技术栈与核心依赖

### 后端与框架

- Ruby on Rails `>= 8.1.2`（`buzzy/Gemfile`）
- Puma（Web 服务）
- Active Record + UUID 主键（`buzzy/config/application.rb`）

### 数据与基础设施

- 数据库适配器由 `DATABASE_ADAPTER` 切换（`sqlite` 默认，`mysql` 可选）：
  - `buzzy/config/database.sqlite.yml`
  - `buzzy/config/database.mysql.yml`
  - `buzzy/config/database.yml`
- Action Cable：`solid_cable`
- 队列：`solid_queue`
- 缓存：`solid_cache`

### 前端

- Turbo + Stimulus + Importmap + Propshaft
- 无 Node 构建链路依赖（通过 Importmap 管理前端包）

### 存储

- Active Storage 本地磁盘
- S3 / MinIO 兼容对象存储（`buzzy/config/storage.oss.yml`）

## 3. 当前实现中的关键架构特征

## 多租户机制（路径前缀）

- 通过中间件 `AccountSlug::Extractor` 从 URL 前缀提取 account UUID，并写入 `Current.account`
- 采用 `script_name` 挂载方式实现租户隔离（`buzzy/config/initializers/tenanting/account_slug.rb`）
- 当前仅支持 UUID 形式的账户路径前缀

## 账户与成员模式

- `Account` 仍是租户边界
- `User` 模型实现了“单账户单真实用户（外加 system 用户）”限制（测试环境放宽）
- 路由中已移除 join-by-code 入口（见 `buzzy/config/routes.rb` 注释）

## 认证与会话

- 主登录方式：Magic Link（无密码）
- 支持 Bearer Token（个人访问令牌）
- 支持 Forward Auth（反向代理注入身份头）可选接入

## 审计与删除语义

- `SoftDeletable`：destroy 默认软删除（写 `deleted_at`），支持 `real_destroy`
- `OperationLog`：通用操作流水（create/update/destroy）
- `SensitiveAuditLog`：敏感行为审计（删卡、删板、冻结用户、导出等）

## 4. 业务域划分（按实现）

### 核心实体

- 账户与身份：`Account`、`Identity`、`User`、`Session`、`MagicLink`
- 协作对象：`Board`、`Column`、`Card`、`Comment`、`Tag`、`Assignment`、`Reaction`
- 可见性与访问：`Access`、`Pin`、`Watch`
- 事件与通知：`Event`、`Notification`、`Push`、`Notifier`
- 对外集成：`Webhook`（含投递与重试相关模型/任务）

### 控制器组织

路由按命名空间拆分明确，包括但不限于：

- `account/*`：账户导入导出、设置、取消
- `users/*`：用户视角（看板、卡片、头像、角色、导出）
- `cards/*`、`columns/*`、`boards/*`：核心看板对象操作
- `my/*`：当前身份配置（locale、timezone、token、pin）
- `notifications/*`：通知设置与读取
- `admin/*`：管理员跨租户治理（看板锁、用户冻结、任务后台）

## 5. 异步与定时机制

- Active Job 统一使用 Solid Queue
- Job 会序列化 account 上下文，并在执行时恢复（`buzzy/config/initializers/active_job.rb`）
- 定时任务在 `buzzy/config/recurring.yml` 定义，覆盖通知聚合、数据清理、标签清理、导入导出清理、账户焚毁等

## 6. 与文档现状相关的结论

- 当前 `docs/` 原有内容偏数据库性能主题
- 核心实现说明原先分散在 `buzzy/README.md`、`buzzy/AGENTS.md` 以及上游文档目录
- `buzzy/README.md` 中引用的 `docs/development.md`、`docs/deployment.md` 已在当前仓库补齐
- Forward Auth 在代码与 `.env.example` 中已有配置入口，但仓库内仍缺少独立的 Forward Auth 使用文档
