# Buzzy vs Fizzy 差异分析报告

本文面向 `buzzy/` 与 `fizzy/` 的对照分析，目标是给出可复核、可追踪、可用于后续演进决策的差异结论。

## 分析对象与方法

- 对象映射：
  - `buzzy/`：Buzzy 分支项目
  - `fizzy/`：Fizzy 上游项目
- 方法：
  - 文档与入口文件对照（`README.md`、`AGENTS.md`、`docs/`）
  - 关键代码路径对照（`routes`、`controllers`、`models`、`initializers`）
  - 文件集合统计与变更分布统计（过滤运行时与本地噪声）

## 定量差异概览（过滤噪声后）

- Buzzy 文件数：1622
- Fizzy 文件数：1580
- 仅 Buzzy 存在：248
- 仅 Fizzy 存在：206
- 公共路径内容变化：589
- 变化文件类型分布（Top）：
  - `.rb`：317
  - `.erb`：207
  - `.yml`：16
  - `.css`：12
  - `.js`：12
- 变化测试文件：91（约占变化文件总数 15.4%）

> 说明：统计已排除 `.env`、`.DS_Store`、数据库数据目录等非业务代码噪声。

## 综合差异分析

### 文档与产品定位

- Buzzy 在 `README.md` 明确声明是 Fizzy 的 fork，并补充了更多“自部署落地”导向说明。
- Buzzy 新增了较完整的本地化文档集，例如：
  - `docs/forward_auth.md`
  - `docs/buzzy-configuration-reference.md`
  - `docs/buzzy-routing-authz.md`
- Fizzy 文档更偏向上游标准能力说明，保留 API 与官方部署指引（例如 `docs/API.md`、`docs/docker-deployment.md`、`docs/kamal-deployment.md`）。

### 代码结构与行为差异

- Buzzy 引入了 Forward Auth 整体能力链：
  - 配置对象：`lib/forward_auth/config.rb`
  - 初始化：`config/initializers/forward_auth.rb`
  - 认证流程接入：`app/controllers/concerns/authentication.rb`
  - 对应测试：`test/lib/forward_auth/config_test.rb`
- 账号前缀策略变化：
  - Fizzy 使用 `external_account_id` 数字前缀（`config/initializers/tenanting/account_slug.rb`）
  - Buzzy 使用 UUID 路径前缀（同路径文件）
- 路由域明显分化：
  - Buzzy 新增 `square/*`、扩展 `admin/*`、用户维度板卡入口（`users/:id/boards`、`users/:id/cards`）
  - Fizzy 保留 `public/*` 与 join-code 流程（`get/post join/:code`）
- Buzzy 在控制器中新增了大量跨账号可见性、受限权限、fallback 用户与 turbo-frame 兼容处理逻辑（`ApplicationController`、`UsersController`、`Sessions::MenusController`）。

### 工程治理与质量差异

- Buzzy 在分叉演进过程中同步推进依赖升级，整体依赖栈更贴近当前运行环境与安全基线（可从 `Gemfile.lock` 与相关初始化代码变更侧面体现）。
- Buzzy 对依赖与配置入口进行了收敛，减少重复能力与历史包袱带来的维护面，降低部署与升级过程中的冲突概率。
- Buzzy 在测试侧补齐了分叉关键能力的覆盖，尤其是 Forward Auth、租户前缀与权限分支相关路径，使核心改动具备稳定的回归基础。

### 风险与可演进性

- Buzzy 认证入口更依赖反向代理与 Header 信任链，网关配置成为可用性的关键点。
- 权限路径分支增多（同账号、跨账号、提及回退、公开回退、super admin），维护成本上升。
- 与上游公共路径差异较大（589），未来同步上游更新成本持续抬升。
- Buzzy 通过特性开关提升了策略控制能力，例如导出禁用、邮箱隐藏等。

### 综合判断

- Buzzy 技术路线偏“可控性优先”；Fizzy 偏“通用性与上游一致性优先”。
- 对部署受控、统一网关身份接入的场景，Buzzy 更合适；对低维护分叉与上游追踪场景，Fizzy 更合适。

## 主题差异清单

### 1) 认证与会话

- Buzzy：支持 Forward Auth，认证顺序为优先尝试网关身份，再回落到 session/bearer。
- Fizzy：标准 magic link + session + bearer，不含 Forward Auth 可信链。

### 2) 租户寻址

- Buzzy：URL 中租户前缀使用 UUID（hyphenated UUID）。
- Fizzy：URL 前缀使用 `external_account_id` 数字编码。

### 3) 账号协作模型

- Buzzy：弱化 join-by-code，强调单账号受控与跨账号受限可见逻辑。
- Fizzy：保留 join-code 与公开资源路由体系。

### 4) 运维与配置

- Buzzy：增加面向网关接入与隐私控制的配置项（例如 `HIDE_EMAILS`、Forward Auth 系列）。
- Fizzy：保持官方部署与 SaaS 兼容文档路径，配置体系更贴近上游默认。

### 5) 上游同步成本

- Buzzy：核心目录（`app/`、`test/`、`config/`）差异密集，后续 rebase 复杂度高。
- Fizzy：作为上游基线，变更结构更稳定且自洽。

### 6) 依赖与测试工程化

- Buzzy：在差异演进中持续推进依赖升级与依赖收敛，并针对新增能力补齐测试，强调“可运行 + 可回归”。
- Fizzy：依赖与测试体系以通用上游节奏为主，更强调基线一致性与广泛兼容性。

## 适用场景建议

- 优先选择 Buzzy 的场景：
  - 需要统一 SSO/反向代理身份接入
  - 需要对导出、邮箱展示等能力做策略收敛
  - 更看重私有化部署可控性，而非与上游完全一致
- 优先保持 Fizzy 基线的场景：
  - 希望长期低成本跟进上游
  - 依赖 join-code/public 路由等上游标准能力
  - 不希望引入网关认证链路复杂度

## 证据索引（关键文件）

- 文档与定位：
  - `buzzy/README.md`
  - `fizzy/README.md`
  - `buzzy/AGENTS.md`
  - `fizzy/AGENTS.md`
- 认证与 Forward Auth：
  - `buzzy/config/initializers/forward_auth.rb`
  - `buzzy/lib/forward_auth/config.rb`
  - `buzzy/app/controllers/concerns/authentication.rb`
  - `fizzy/app/controllers/concerns/authentication.rb`
- 租户前缀机制：
  - `buzzy/config/initializers/tenanting/account_slug.rb`
  - `fizzy/config/initializers/tenanting/account_slug.rb`
  - `buzzy/test/middleware/account_slug_extractor_test.rb`
  - `fizzy/test/middleware/account_slug_extractor_test.rb`
- 路由差异：
  - `buzzy/config/routes.rb`
  - `fizzy/config/routes.rb`
- 全局能力开关：
  - `buzzy/lib/buzzy.rb`
  - `fizzy/lib/fizzy.rb`
