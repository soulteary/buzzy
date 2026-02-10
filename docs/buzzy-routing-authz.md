# Buzzy 路由、认证与权限说明

## 1. 路由入口与分区

主路由文件：`buzzy/config/routes.rb`

- 根路径：`/` -> `events#index`
- 账户域：`account/*`
- 用户域：`users/*`
- 看板/列/卡片域：`boards/*`、`columns/*`、`cards/*`
- 通知域：`notifications/*`
- 当前身份域：`my/*`
- 管理域：`admin/*`
- 广场域：`square/*`
- 健康检查：`/up`
- PWA：`/manifest`、`/service-worker`

## 2. 多租户路由解析（路径前缀）

核心实现：`buzzy/config/initializers/tenanting/account_slug.rb`

请求流程要点：

1. 从 URL 前缀解析 account UUID
2. 将前缀移入 `script_name`，并重写 `path_info`
3. 通过 `Current.with_account(account)` 注入租户上下文
4. 控制器中 `default_url_options` 自动带 `script_name`

此外，对无账户前缀的 `/users/:id`，中间件会根据目标用户反推账户并设置上下文，避免跳转循环。

## 3. 认证链路

核心模块：`buzzy/app/controllers/concerns/authentication.rb`

默认执行顺序：

1. `set_account_from_identity_when_single`
2. `require_account`
3. `require_authentication`
4. `require_user_in_account`

认证方式（按代码实际）：

- Forward Auth（若启用且请求可信，优先）
- 已有 cookie session 恢复
- Bearer Token（个人访问令牌）
- 否则进入登录流程（Magic Link）

Magic Link 的开发态行为：会将验证码写入响应头 `X-Magic-Link-Code` 与 flash（仅 development）。

## 4. 权限模型

## 角色与身份

- `Identity`：跨账户的全局身份（邮箱）
- `User`：账户内成员记录（owner/admin/member/system）

## 管理员能力

- 超级管理员由 `ADMIN_EMAILS` 决定（`ApplicationController#super_admin?`）
- 可访问 `admin/all_content`，并执行跨账户管理操作

## 典型限制

- 非同账户用户在多数写操作路径下会被拦截
- 看板编辑锁（`edit_locked`）启用后，普通成员不可编辑
- “查看他人资源”场景存在专门的可见性与只读策略分支

## 5. 安全审计与操作流水

## 操作流水（OperationLog）

- 记录 create/update/destroy
- 关联 account/board/user/subject/request_id/ip
- 由 `OperationLoggable` concern 自动写入

## 敏感审计（SensitiveAuditLog）

记录高风险动作，例如：

- 删除卡片/看板/账户
- 冻结/解冻用户
- 锁定/解锁看板可见性与编辑
- 触发账户导出/用户导出

软删除流程（`SoftDeletable`）会同时触发敏感审计与操作流水。

## 6. 管理端路由行为说明

管理端重点路由位于 `admin/*`：

- 看板锁：
  - `admin/boards/:id/toggle_visibility_lock`
  - `admin/boards/:id/toggle_edit_lock`
- 用户冻结：
  - `admin/users/:id/freeze`
  - `admin/users/:id/unfreeze`
- 作业后台：
  - `MissionControl::Jobs::Engine` 挂载于 `admin/jobs`

这些操作均要求超级管理员权限，并在控制器中写入敏感审计记录。
