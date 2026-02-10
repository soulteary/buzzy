# MySQL 性能检查清单

> 不改变业务逻辑为前提的系统性检查与可选优化建议。

## 已执行的优化（可直接使用）

| 项 | 说明 |
|----|------|
| **Bullet** | Gemfile 中已加入 `group :development, :staging` 的 `bullet`。development 下默认开启 N+1/未使用预加载检测；设置 `BULLET_ENABLED=false` 可关闭。staging 下需设置 `BULLET_ENABLED=true` 才会开启。 |
| **可选索引迁移** | `20260211100001` events(account_id, created_at)、`20260211100002` operation_logs(action, created_at)、`20260211100003` cards(board_id, number)、`20260211100004` comments(card_id, created_at)；按需执行 `bin/rails db:migrate`。其中 20260211100002 在 SQLite 下也会执行（索引与 MySQL 对齐，见 docs/sqlite-performance.md）。 |
| **索引验证任务** | 使用 MySQL/Trilogy 时执行 `bin/rails db:mysql:check_indexes` 可验证 events / operation_logs / sensitive_audit_logs / search_records_0..15，并对 operation_logs/cards/comments 可选索引做提示。使用 SQLite 时执行 `bin/rails db:sqlite:check_indexes`（见 docs/sqlite-performance.md）。 |
| **慢查询帮助任务** | 执行 `bin/rails db:mysql:slow_query_log_help` 可输出 MySQL 慢查询日志开启命令，便于复制到会话或 my.cnf。 |
| **慢查询日志** | 详见下文「4.2 慢查询与 APM」及上述 rake 任务。 |

---

## 1. 索引：表与索引是否真实存在

### 1.1 执行前准备

- 使用 MySQL 配置时：通过 `DATABASE_ADAPTER=mysql` 加载 `config/database.mysql.yml`（见 `Buzzy.db_adapter`），确认 `RAILS_ENV` 与目标库一致。
- 执行索引验证：在 MySQL 环境下运行 `bin/rails db:mysql:check_indexes`（非 MySQL 时会自动跳过）。
- 建议：在 **staging** 或从 **production 导出的副本** 上执行检查与慢查询分析，避免影响线上。

### 1.2 检查 events 表及索引

迁移与 `db/schema.rb` 中已定义以下索引，需在 MySQL 中确认存在：

| 表名   | 索引名 | 列 |
|--------|--------|-----|
| events | index_events_on_account_id_and_action | (account_id, action) |
| events | index_events_on_board_id_and_action_and_created_at | (board_id, action, created_at) |
| events | index_events_on_board_id | (board_id) |
| events | index_events_on_creator_id | (creator_id) |
| events | index_events_on_eventable | (eventable_type, eventable_id) |

**验证命令示例：**

```sql
SHOW INDEX FROM events;
```

或：

```sql
SELECT index_name, column_name, seq_in_index
FROM information_schema.statistics
WHERE table_schema = DATABASE() AND table_name = 'events'
ORDER BY index_name, seq_in_index;
```

### 1.3 检查 operation_logs 表及索引

- 表与索引由迁移定义：`db/migrate/20260210120000_create_operation_logs.rb`（及后续重命名字段迁移）。
- 若当前 `db/schema.rb` 的 version 早于 20260210120000，需先执行 `bin/rails db:migrate` 再检查。

预期索引：

| 表名           | 索引名 | 列 |
|----------------|--------|-----|
| operation_logs | index_operation_logs_on_account_id | (account_id) |
| operation_logs | index_operation_logs_on_board_id | (board_id) |
| operation_logs | index_operation_logs_on_user_id | (user_id) |
| operation_logs | index_operation_logs_on_subject_type_and_subject_id | (subject_type, subject_id) |
| operation_logs | index_operation_logs_on_account_id_and_created_at | (account_id, created_at) |
| operation_logs | index_operation_logs_on_board_id_and_created_at | (board_id, created_at) |

若已执行可选迁移 `20260211100002`，还会有 `index_operation_logs_on_action_and_created_at` (action, created_at)。

**验证：** `SHOW INDEX FROM operation_logs;`

### 1.4 检查 sensitive_audit_logs 表及索引

- 迁移：`db/migrate/20260210130000_create_sensitive_audit_logs.rb`。

预期索引：

| 表名                 | 索引名 | 列 |
|----------------------|--------|-----|
| sensitive_audit_logs | index_sensitive_audit_logs_on_account_id | (account_id) |
| sensitive_audit_logs | index_sensitive_audit_logs_on_user_id | (user_id) |
| sensitive_audit_logs | index_sensitive_audit_logs_on_subject_type_and_subject_id | (subject_type, subject_id) |
| sensitive_audit_logs | index_sensitive_audit_logs_on_account_id_and_created_at | (account_id, created_at) |
| sensitive_audit_logs | index_sensitive_audit_logs_on_action_and_created_at | (action, created_at) |

**验证：** `SHOW INDEX FROM sensitive_audit_logs;`

### 1.5 检查 search_records_0..15 与 FULLTEXT（ngram）

- 16 张分表：`search_records_0` … `search_records_15`。
- 每表应有：`account_id` 索引、唯一索引 `(searchable_type, searchable_id)`、FULLTEXT(account_key, content, title) **WITH PARSER ngram**。

**验证示例（单表）：**

```sql
SHOW INDEX FROM search_records_0;
SHOW CREATE TABLE search_records_0\G
```

确认 FULLTEXT 索引为 ngram 解析器（见迁移 `20260207100000_use_ngram_fulltext_for_search_records.rb`）。

---

## 2. N+1：活动流、看板列表、卡片列表、Event 预加载

### 2.1 已使用 preload/includes 的路径（保持即可，仅做确认）

- **活动流 / Event 列表**
  - `User::DayTimeline` → `Event.preloaded.only_kept_eventables.where(...)`  
  - `Event.preloaded` 在 `app/models/event.rb` 中定义为：  
    `includes(:creator, :board, eventable: [ :goldness, :closure, :image_attachment, { rich_text_body: :embeds_attachments }, { rich_text_description: :embeds_attachments }, { card: [ :goldness, :closure, :image_attachment ] } ])`  
  - 活动流按「天」窗口查询，已按 board、action 过滤，结合 `index_events_on_board_id_and_action_and_created_at` 使用合理。

- **看板列表**
  - `BoardsController#index`：`boards_scope.includes(:creator, :account)`  
  - 已预加载 creator、account，避免列表 N+1。

- **卡片列表**
  - `BoardsController` / `CardScoped` 中卡片列表：  
    `@board.cards.awaiting_triage.latest.with_golden_first.preloaded`  
  - `Card.preloaded`（`app/models/card.rb`）：  
    `with_users.preload(:column, :tags, :steps, :closure, :goldness, :activity_spike, :image_attachment, reactions: :reacter, board: [ :entropy, :columns ], not_now: [ :user ]).with_rich_text_description_and_embeds`  
  - 已覆盖列表页常用的 board、creator、assignees、column、tags 等。

- **评论列表**
  - `Cards::CommentsController`：`@card.comments.chronologically.preloaded`  
  - `Comment.preloaded`：`with_rich_text_body.includes(:creator, :event, reactions: :reacter)`。

- **搜索**
  - `Search::Record::Trilogy` / `Search::Record`：  
    `.includes(:searchable, card: [ :board, :creator ])`  
  - 搜索结果已预加载 card、board、creator。

### 2.2 建议用 Bullet 或手查的路径

- **Bullet（已配置）**  
  - **development**：默认开启；关闭请设置环境变量 `BULLET_ENABLED=false`。  
  - **staging**：需设置 `BULLET_ENABLED=true` 才会开启（config/environments/staging.rb）；Gemfile 中 bullet 已在 `group :development, :staging`。  
  - 重点跑：活动流首页、看板列表、看板内卡片列表、用户时间线、搜索页、单卡详情（含评论）。

- **手查要点**
  - 活动流：确认 `Event.preloaded` 在 `DayTimeline#filtered_events` 链上被调用（已确认）。
  - 列表页：确认未在视图中对 `board`/`card`/`creator` 再触发未预加载的关联（如 `card.board` 在 preloaded 下已加载）。
  - 若发现 N+1：在对应 controller 或 scope 中补 `includes`/`preload`，尽量不改业务逻辑。

---

## 3. 搜索：连接池与分片键

### 3.1 分表与分片键

- **分表**：`search_records_0` … `search_records_15`（16 张）。
- **分片键**：`account_id` → `shard_id = Zlib.crc32(account_id.to_s) % 16`（`Search::Record::Trilogy.shard_id_for_account`）。
- **FULLTEXT**：每表 `(account_key, content, title)`，ngram；查询中带 `+account{account_id}`，与 `account_key` 一致，利于按账号隔离并走索引。

### 3.2 高并发下连接池

- **config/database.mysql.yml** 中已设：`pool: 50`，`timeout: 5000`。
- 搜索请求会按 `account_id` 只命中一个分表，单次请求不跨库；多请求并发时共享同一 connection pool。
- **建议**：若搜索 QPS 很高，可结合 staging 压测观察连接池使用率与超时；必要时按环境调大 `pool` 或配合 PgBouncer/ProxySQL 等（当前为 Trilogy/MySQL）。

### 3.3 可选检查

- 确认搜索接口始终传入 `account_id`（或从 current user 推导），保证分片键稳定。
- 多账号可见搜索（`search_all_visible_trilogy`）会轮询多个 account，每个 account 一次分表查询，连接复用仍为同一 pool。

---

## 4. 连接池与慢查询

### 4.1 当前配置（config/database.mysql.yml）

| 项     | 值    | 说明 |
|--------|-------|------|
| pool   | 50    | 每进程最大 DB 连接数 |
| timeout| 5000  | 连接超时（毫秒） |

- 生产若为多进程/多机部署，总连接数 ≈ 进程数 × 50，需低于 MySQL `max_connections`。
- 可根据实际并发在 staging 压测后微调 `pool` 与 MySQL 端 `max_connections`。

### 4.2 慢查询与 APM

- **开启慢查询日志（staging/生产只读副本）**  
  - 在 MySQL 会话或配置中设置（示例，按需调整阈值）：  
    ```sql
    SET GLOBAL slow_query_log = 'ON';
    SET GLOBAL long_query_time = 2;
    SET GLOBAL slow_query_log_file = '/var/lib/mysql/slow.log';
    -- 可选：记录未使用索引的查询
    SET GLOBAL log_queries_not_using_indexes = 'ON';
    ```  
  - 持久化需写入 `my.cnf` / `mysqld` 配置：`slow_query_log=1`、`long_query_time=2` 等。  
  - 分析慢日志中出现的表与条件，对照下面「可选优化建议」加索引或改写。

- **APM**  
  - 若已有 New Relic / Scout / Datadog 等，抓取慢 SQL、按表/控制器排序，优先优化 Top N。

### 4.3 针对慢 SQL 的后续动作

- 对慢 SQL：记录表名、WHERE/ORDER BY 列、是否已有合适索引。
- 先加索引或改写查询（不改变业务逻辑）；必要时再考虑查询拆分或缓存。

---

## 5. 可选索引 / 查询优化建议（具体表名与索引名）

以下在「确认慢查询或 EXPLAIN 显示全表扫描/临时表」后再考虑实施。

### 5.1 events

- **已有**：`index_events_on_board_id_and_action_and_created_at`、`index_events_on_account_id_and_action` 等，活动流按 board + action + 时间窗口已覆盖。
- **可选**：若出现按 **account_id + created_at** 的列表/报表查询且较慢，可加：  
  - 索引名：`index_events_on_account_id_and_created_at`  
  - 列：`(account_id, created_at)`  
  - 仅在有明确慢查询且 EXPLAIN 显示需要时添加。

### 5.2 operation_logs

- **已有（迁移中）**：`(account_id, created_at)`、`(board_id, created_at)`。
- **可选**：若有按 **action** 的审计检索且慢，可考虑：  
  - 索引名：`index_operation_logs_on_action_and_created_at`  
  - 列：`(action, created_at)`  
  - 仅在有该查询模式且被慢日志/APM 抓到时添加。

### 5.3 sensitive_audit_logs

- **已有（迁移中）**：`(account_id, created_at)`、`(action, created_at)`。
- 一般无需再增索引，除非出现新的过滤维度（如 user_id + created_at）且被慢查询证实。

### 5.4 search_records_*（0..15）

- 已有 `account_id`、唯一 `(searchable_type, searchable_id)`、FULLTEXT(account_key, content, title) ngram。
- **建议**：保持查询条件包含 `account_id`（或 account_key），避免全表扫描；高并发下重点看连接池与慢查询，而非再加索引。

### 5.5 其他表（按慢查询再定）

- **cards**：若出现按 `board_id + number` 的慢查询，可执行迁移 `20260211100003` 添加 `index_cards_on_board_id_and_number`。若为 `board_id + column_id + created_at`，再视情况加复合索引。
- **comments**：若按 `card_id + created_at` 列表慢，可执行迁移 `20260211100004` 添加 `index_comments_on_card_id_and_created_at`。

---

## 6. 检查项汇总（一页清单）

| # | 类别       | 检查项 |
|---|------------|--------|
| 1 | 索引       | MySQL 中 `events` 表及 5 个索引存在且与 schema 一致 |
| 2 | 索引       | 已跑 migration 时，`operation_logs`、`sensitive_audit_logs` 表及迁移中定义的索引存在 |
| 3 | 索引       | `search_records_0`…`15` 存在，且 FULLTEXT 为 ngram |
| 4 | N+1        | 活动流、看板列表、卡片列表、Event/Comment 预加载路径用 Bullet 或手查，无新增 N+1 |
| 5 | 搜索       | 分片键（account_id）与连接池（pool/timeout）在高压下合理 |
| 6 | 慢查询     | staging 开启 slow query log 或 APM，抓取慢 SQL |
| 7 | 优化       | 根据慢 SQL 与 EXPLAIN 对具体表加索引或改写查询（见上文可选建议） |

完成上述检查并记录结果后，可将「MySQL 性能检查」标记为已完成；后续优化以慢查询与 EXPLAIN 为准，按表名与索引名逐条落实。
