# Buzzy 项目对比报告：原始版 Buzzy vs 改进版

本文档对仓库内 **origin-project**（37signals 官方开源 Buzzy）与 **buzzy**（改进版，代码位于 `buzzy/` 目录）做逐项对比，基于当前代码与配置，供选型、迁移与二次开发参考。

---

## 概述

- **origin-project**：上游 Buzzy，面向「自建或小幅定制」；多租户 URL 使用数字 ID，保留公开看板/卡片与账户下 join_code、多用户管理。
- **buzzy（改进版）**：在官方基础上增强路由（按用户维度、关注）、认证（Forward Auth）、i18n（中英）、管理（看板锁、用户冻结、all_content）、搜索（跨账号 + CJK），并做了 Legacy 瘦身（账号仅 UUID、卡片仅看板内入口、错误上下文用 account.id）。移除公开未登录入口与 join 路由，账户设置偏向单人使用与运维开关。

二者数据模型一致（Account → User、Board、Card 等），差异集中在路由、中间件、认证、i18n、Admin 与运维配置。

---

## 一、项目与结构概览

| 维度 | origin-project | buzzy（改进版） |
|------|----------------|-----------------|
| **config** | ~53 个文件 | ~101 个（含 locales 分模块、forward_auth、i18n_fallbacks、sqlite_wal 等） |
| **locales** | 仅 `config/locales/en.yml` | `en/`、`zh/` 分模块 + `en.yml`、`zh.yml`，`available_locales = [:en, :zh]` |
| **docs** | 4：API、development、docker、kamal | 合并后见 [README](./README.md) |
| **多租户 URL** | 数字 ID 前缀 `/{external_account_id}/...` | 仅 UUID 前缀 `/{account.id}/...`，数字/base36 请求 404 |
| **公开看板/卡片** | 有 `namespace :public`、`direct :published_board/card` | 已移除，仅认证用户 + 跨用户「查看他人」路由 |
| **仓库元数据** | 有 .dockerignore、.gitleaksignore、CONTRIBUTING.md、STYLE.md、.github/ISSUE_TEMPLATE | 有 .env.example（Forward Auth、ADMIN_EMAILS、DISABLE_*、HIDE_EMAILS）、.rubocop.yml、AGENTS.md；buzzy 亦有 .dockerignore、.gitleaksignore |

---

## 二、功能与架构对比

### 2.1 路由与 URL

| 能力 | origin-project | buzzy |
|------|----------------|-------|
| **账户前缀** | 数字 `external_account_id`，中间件 `AccountSlug::PATTERN = /(\d+)/`，`Account.find_by(external_account_id:)` | 仅带连字符 UUID，`HYPHENATED_UUID_PATTERN`，`Account.find_by(id: slug)`；数字/base36 不 302，直接 404。URL 解析不使用 `external_account_id` |
| **用户与看板/卡片** | `resources :users` 无 `/users/:id/boards`、`/users/:id/cards` 等子资源；卡片可经 `/cards/:id`、`/collections/:collection_id/cards/:id` | `/users/:id`、`/users/:id/boards`、`/users/:id/cards`、`/users/:id/boards/:board_id/cards/:id`；卡片**仅**看板内路径，无 `/cards/:id`、`/collections/.../cards/:id`（已移除路由与 CardRedirectsController） |
| **看板下卡片** | `/boards/:id` 下嵌套 cards | 同左；columns 的 `:id` 约束为 UUID，避免与 not_now/closed 等冲突 |
| **公开看板/卡片** | `namespace :public`，Public::BaseController，`/public/boards/:id`、`/public/boards/:board_id/cards/:id` | 已移除；改为认证 + 他人看板/卡片及 all_access 可见性 |
| **关注** | 无 | `post follow/:user_id`、`delete unfollow/:user_id`，Square::FollowingController |
| **我的 / 会话** | my：access_tokens、identities、pins、timezone、menu；sessions/transfers | 增加 my/locale、my/session_transfer；sessions 仍含 transfers |
| **Join** | account 下 `resource :join_code`；全局 `get/post "join/:code"` → JoinCodesController | 无 account 下 join_code 资源；顶层 **join 路由已注释移除**（单用户/账户）；JoinCodesController 与视图仍存在但无路由 |
| **Legacy 重定向** | `/collections/:id` → `/boards/:id` 等 | **仍支持**：`/user/:id` → `/users/:id`，`/collections/:id` → `/boards/:id`。详见 [legacy-urls.md](./legacy-urls.md) |

### 2.2 多租户与中间件

- **origin-project**：`AccountSlug` 仅匹配数字，`encode(id)` 为数字字符串，查表用 `external_account_id`。无「无前缀 /users/:id 时按被查看用户设 Current.account」的逻辑。
- **buzzy**：仅匹配带连字符 UUID，`Account.find_by(id: slug)`。无 account 前缀的 `/users/:id` 时，用被查看用户所在 account 设置 `Current.account`，便于无前缀用户页与跨账号访问。注释标明 `external_account_id` 不用于 URL，仅用于兼容/SAAS/脚本。

### 2.3 认证与运维

| 项目 | origin-project | buzzy |
|------|----------------|-------|
| **Forward Auth** | 无 | 有；`config/initializers/forward_auth.rb`、[forward_auth.md](./forward_auth.md)；信任 IP/Secret Header、自动建 Identity/User/Account、锁邮箱等 |
| **ApplicationController** | 无 SetLocale、无 script_name、无 set_account_from_user_path / set_context_user | SetLocale、`default_url_options` 注入 `script_name: Current.account.slug`、`prepend_before_action :set_account_from_user_path`、`set_context_user`；`rescue_from RecordNotFound` 对 Turbo Frame 返回空 frame |
| **lib/buzzy.rb** | 仅 saas?、db_adapter、configure_bundle | 增加 session_transfer_enabled?、export_data_enabled?、hide_emails?、admin_emails（ADMIN_EMAILS） |
| **错误上下文** | — | `config/initializers/error_context.rb` 使用 `Current.account&.id`（不用 external_account_id） |

### 2.4 搜索

- **作用域**：origin 仅当前账号 + 当前用户 board_ids（`Search::Record.for(account_id).search(...)`）；buzzy 为 `search_all_visible`，含本账号 + **跨账号 all_access 看板**（User::Searcher#searchable_account_board_ids）。
- **字符处理**：origin `terms.gsub(/[^\w"]/, " ")`；buzzy `terms.gsub(/[^\p{L}\p{N}\p{M}\s"]/, " ")`，支持 CJK/Unicode。

### 2.5 国际化 (i18n)

- **origin-project**：仅 `en.yml`，无 available_locales 配置。
- **buzzy**：`default_locale = :en`、`available_locales = [:en, :zh]`，`config/locales/en/`、`zh/` 按模块拆分，`i18n_fallbacks.rb`；my/locale 支持界面语言切换；[i18n.md](./i18n.md) 说明 i18n 与添加新语言。

### 2.6 管理后台

- **origin-project**：`namespace :admin` 仅 `mount MissionControl::Jobs`。
- **buzzy**：admin 增加 all_content、boards/:id/toggle_visibility_lock、toggle_edit_lock、users/:id/freeze、unfreeze；配合 super_admin?（ADMIN_EMAILS）做跨账户查看与成员管理。

### 2.7 控制器与 Concern

| 项目 | origin-project | buzzy |
|------|----------------|-------|
| **account/** | cancellations、entropies、exports、imports、**join_codes**、settings | 无 join_codes；settings 仅 show |
| **boards/** | columns、entropies、involvements、**publications** | 无 publications 控制器（Publication 模型仍在） |
| **public/** | base_controller、boards、cards | 无；已移除 |
| **admin/** | 仅 admin_controller + MissionControl::Jobs | admin/all_content、boards、users |
| **square/** | 无 | all_content、following |
| **users/** | avatars、data_exports、email_addresses、events、joins、push_subscriptions、roles、verifications | 增加 **boards**、**cards** |
| **my/** | access_tokens、identities、menus、pins、timezones | 增加 **locales**、**session_transfers** |
| **Concerns** | 无 SetLocale、UserAccountFromPath | SetLocale、UserAccountFromPath、all_content_users_list |
| **CardScoped** | 极简：set_card → set_board | 支持 user_id 下按被查看用户取 board；多级 fallback（可访问 → 公开看板+已发布 → 提及）；ensure_board_visible_to_limited_viewer、ensure_board_editable 等 |
| **Authentication** | require_authentication = resume_session \|\| bearer \|\| request_authentication | 增加 set_account_from_identity_when_single、require_user_in_account；require_authentication 首位 authenticate_by_forward_auth；Turbo 空 frame 处理 |

### 2.8 Current、User、Identity、Board

| 项目 | origin-project | buzzy |
|------|----------------|-------|
| **Current** | session, user, identity, account, http_method, request_id, user_agent, ip_address, referrer | 新增 **context_user**、**user_before_fallback** |
| **User** | 无 follow、无 frozen_by | user_follows / followed_users / followers；belongs_to :frozen_by；single_real_user_per_account 校验；User::AllContentList |
| **UserFollow** | 无 | 新模型 follower_id、followee_id |
| **Identity** | 无 locale、email_locked、session_transfer_enabled；Transferable 仅 signed_id | locale、email_locked、session_transfer_enabled；Identity::TransferToken + Transferable 双轨 |
| **Board** | 无锁字段 | visibility_locked、edit_locked、*_at、*_by_id；editable_by?、visibility_changeable_by? |

### 2.9 账户设置与视图

| 项目 | origin-project | buzzy |
|------|----------------|-------|
| **account/settings** | 含 _name（账户名）、_users（多用户列表与管理）、resource :join_code（账户下） | 仅 show；profile、theme、language、transfer、access_tokens、data_export；无 _name、_users；受 Buzzy.export_data_enabled?、session_transfer_enabled? 等控制 |
| **文案** | 硬编码英文 | i18n（如 account.settings.show.*） |
| **Forward Auth** | 无 | 设置/登录菜单中可隐藏登出、邮箱编辑等 |

### 2.10 数据库与部署

| 项目 | origin-project | buzzy |
|------|----------------|-------|
| **Schema 扩展** | 无 user_follows、identities 无 locale/email_locked/session_transfer_enabled、boards 无锁、无 identity_transfer_tokens、users 无 frozen_by_id | 有上述表/列及 202602* 等迁移 |
| **MySQL/生产** | 有 database.mysql.yml / sqlite.yml | 另有 table_definition_column_limits、sqlite_wal、Buzzy.db_adapter 选择 |
| **docker** | 有 Dockerfile、.dockerignore | 有 Dockerfile.base、docker-compose、docker/ 下 MySQL 相关脚本；patches/ |

### 2.11 其他行为

- **resolve "Board" / "Card"**：buzzy 根据 Current.context_user 生成 user_board_path / user_board_card_path；origin 无。
- **resolve "Comment"**：origin `route_for :card, comment.card`；buzzy `route_for :board_card, comment.card.board, comment.card`（或带 user 形式）。
- **Account#slug**：origin 数字（AccountSlug.encode(external_account_id)）；buzzy UUID（AccountSlug.encode(self)）。

---

## 三、优劣势与选型建议

### 3.1 改进版 (buzzy) 优势

- **路由与协作**：用户维度路由 + context_user + follow/unfollow，便于「看他人看板/卡片」与简单社交。
- **搜索**：跨账号 all_access 可搜 + CJK/Unicode，适合多语言团队。
- **认证与运维**：Forward Auth、ENV 开关（session_transfer、export、hide_emails、admin_emails），易对接 SSO 与合规；Turbo Frame 友好。
- **i18n**：中英双语与 locale 切换，适合 CJK 用户。
- **URL 与 Legacy**：统一 UUID；卡片仅看板内入口，老链接负担低；[legacy-urls.md](./legacy-urls.md) 明确废弃与仍支持路径；错误上下文用 account.id。
- **管理**：admin all_content、看板可见性/编辑锁、用户冻结，配合 super_admin。
- **数据库与部署**：MySQL 兼容、WAL、docker 脚本，便于生产与迁移。
- **文档**：forward_auth、legacy-urls、routes-boards-cards、i18n、deployment，便于运维与二次开发。

### 3.2 改进版 (buzzy) 劣势与风险

- **公开分享**：无未登录可访问的公开看板/卡片链接。
- **账户/卡片 URL**：数字/base36 账号前缀 404，需迁移到 UUID；卡片老链接已移除，仅看板内入口。
- **复杂度**：CardScoped、Authentication、ApplicationController 等逻辑更重，排错与测试成本更高。
- **账户设置**：无账户名与多用户列表管理；join 路由已注释移除，无邀请入口。
- **上游同步**：相对官方改动多，合并上游时冲突与回归风险较大。

### 3.3 原始版 (origin-project) 优势

- **简单**：路由与控制器更少，CardScoped 极简，无 Forward Auth/SetLocale/script_name/require_user_in_account，易理解、易跟上游。
- **公开链接**：保留 public 看板/卡片与 published_board/card。
- **贡献与规范**：CONTRIBUTING.md、STYLE.md、.gitleaksignore、ISSUE_TEMPLATE。
- **账户设置**：账户名、多用户列表、account 下 join_code + 全局 join/:code。

### 3.4 原始版 (origin-project) 劣势

- 无按用户维度的看板/卡片路由与关注；搜索仅本账号、字符仅 \w；无 Forward Auth 与丰富 ENV 开关；无 i18n；无看板锁与用户冻结；Admin 仅 Jobs；Identity 无 locale/email_locked/session_transfer_enabled/TransferToken。

### 3.5 选型建议

- **选改进版**：需要中文/多语言、Forward Auth/SSO、跨用户查看与关注、跨账号搜索、更强 admin、MySQL/生产优化，且可接受「无公开未登录链接」「账户/卡片 URL 迁移」「无 join 入口」时。
- **选原始版**：需要「未登录可访问的公开看板/卡片」、与上游尽量一致、英文为主、不需复杂路由与运维开关时。
- **混合**：在改进版上可自行恢复只读公开入口或加回账户名/多用户管理，以兼顾需求。

---

## 四、差异速查表（按模块）

| 模块 | origin-project | buzzy |
|------|----------------|-------|
| 账户 URL | 数字 external_account_id | UUID account.id；数字/base36 404 |
| 用户路由 | 无 /users/:id/boards(cards) | 有，含嵌套 boards/cards |
| 卡片直链 | /cards/:id、/collections/.../cards/:id | 已移除，仅看板内（见 [legacy-urls.md](./legacy-urls.md)） |
| 公开看板/卡片 | 有 public、published_* | 已移除（Publication 模型仍在） |
| 关注 | 无 | follow/unfollow、UserFollow、Square::Following |
| 搜索范围 | 本账号 | 本账号 + 跨账号 all_access |
| 搜索字符 | \w | \p{L}\p{N}\p{M}（含 CJK） |
| Forward Auth | 无 | 有，文档与 initializer 完整 |
| i18n | 仅 en | en + zh，SetLocale，[i18n](./i18n.md) |
| Admin | 仅 Jobs | + all_content、visibility/edit lock、freeze |
| ENV 开关 | 少 | session_transfer、export、hide_emails、admin_emails |
| MySQL/生产 | 基础 | column limits、WAL、docker/mysql 脚本 |
| 文档 | 4 | 合并后见 [README](./README.md) |
| Current | session, user, identity, account, ... | + context_user, user_before_fallback |
| User | 多用户/账户 | + follow、frozen_by、single_real_user_per_account、AllContentList |
| Identity | 无 locale/锁 | locale、email_locked、session_transfer_enabled、TransferToken |
| Board | 无锁 | visibility_locked、edit_locked、editable_by?、visibility_changeable_by? |
| CardScoped | 极简 set_card→set_board | 多级 fallback、limited_viewer、mention、editable 校验 |
| Authentication | resume \|\| bearer \|\| request | + set_account_from_identity_when_single、require_user_in_account、Forward Auth、Turbo 空 frame |
| account/settings | name、users、join_code、entropy、export、cancellation | profile、theme、language、transfer、tokens、export（无 name/users）；join 路由已注释移除 |
| join_code | account 下 resource :join_code；全局 join/:code | 顶层 join 路由已注释移除；无 account 下 join_code |
| 错误上下文 | — | account_id 用 Current.account&.id |

---

## 五、改动量统计（补充）

与功能对比互补的代码级统计（排除 .git、tmp、node_modules、数据目录等）：

| 维度 | 数值 |
|------|------|
| 共有文件 | 1,529 |
| 其中被修改 | 406（约 26.6%） |
| 净增行数 | +2,310 |
| 仅 buzzy 有（新增） | 109 个文件 |
| 仅 origin 有（移除） | 48 个文件 |

改动集中在 **app**（controllers、views、models）；新增文件主要来自 i18n、Forward Auth、用户/看板路由、Admin、文档；移除文件主要来自公开看板/卡片、Join、多用户账户设置。

---

## 六、参考与附录

- **改进版文档**：本目录下 [API](./API.md)、[development](./development.md)、[deployment](./deployment.md)、[forward_auth](./forward_auth.md)、[legacy-urls](./legacy-urls.md)、[routes-boards-cards](./routes-boards-cards.md)、[i18n](./i18n.md)。
- **Legacy 瘦身**：账号仅 UUID 前缀；[legacy-urls.md](./legacy-urls.md) 列出废弃与仍支持路径。
- **分析依据**：基于当前仓库 `origin-project/` 与 `buzzy/` 的代码与配置；选型与迁移请结合部署环境与合规需求自行判断。
