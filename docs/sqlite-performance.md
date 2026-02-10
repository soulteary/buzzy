# SQLite 性能分析与优化

> 以 WAL、单写连接与必要索引为主；与 MySQL 索引策略对齐。

## 现状概览

| 项 | 说明 |
|----|------|
| **WAL** | `config/initializers/sqlite_wal.rb` 已在生产且为 sqlite3 适配器时执行 `PRAGMA journal_mode=WAL`。 |
| **搜索** | SQLite 使用单表 `search_records` + FTS5 虚拟表；Porter 词干 + CJK/LIKE 回退（见 `Search::Record::SQLite`）。 |
| **Openslide** | `config/initializers/vips.rb` 已禁用 `VipsForeignLoadOpenslide`，避免 fork 后 SQLite segfault。 |
| **Schema** | `db/schema_sqlite.rb` 与迁移双适配器一致；`operation_logs`、`sensitive_audit_logs` 在 SQLite 下也有对应索引。 |

---

## 1. WAL：确认生产/部署下已开启

- **实现**：`config/initializers/sqlite_wal.rb`
  - 仅在 `Rails.env.production?` 且当前主连接为 `sqlite3` 时执行。
  - `after_initialize` 中执行 `PRAGMA journal_mode=WAL`，降低多进程写同一库时的「database disk image is malformed」风险。
- **建议**：
  - 部署/生产使用 SQLite 时，确认未覆盖或跳过该 initializer。
  - 若希望在开发/测试下也启用 WAL（与生产行为一致），可改为不判断 `Rails.env.production?`，仅保留 `adapter == "sqlite3"` 判断；当前保守做法是仅生产开启。

---

## 2. 连接与并发：单写、多 worker 注意锁

- **单写**：SQLite 单写多读，避免多进程同时写同一库。同一 DB 文件只应有一个活跃写连接。
- **Puma 多 worker**：
  - 多 worker 同时写同一 SQLite 库会争用锁，易出现 `SQLITE_BUSY` 或阻塞。
  - **建议**：生产或高并发场景优先使用 MySQL/Trilogy；SQLite 仅推荐开发/小规模单实例部署。
  - 若必须多进程访问同一 SQLite：可考虑单 worker、或将写操作集中到单进程（如 Solid Queue 的 queue DB 单独文件），主库只读或单写。
- **Solid Queue**：若使用 SQLite 作为 queue 库，其连接独立于主库，WAL 由 Solid Queue 建立连接时的适配器默认或单独配置；主库 WAL 由 `sqlite_wal.rb` 处理即可。

---

## 3. 索引：与 MySQL 一致

- **策略**：Rails 迁移中的 `add_index` 在 MySQL 与 SQLite 上都会执行（未在迁移里 `return if connection.adapter_name == "SQLite"` 的迁移）。
- **operation_logs**：已与 MySQL 对齐，在 SQLite 下同样创建可选索引 `(action, created_at)`（迁移 `20260211100002` 已改为双适配器执行；`db/schema_sqlite.rb` 已包含该索引）。
- **sensitive_audit_logs**：建表迁移中已包含 `(account_id, created_at)`、`(action, created_at)` 等索引，双适配器一致。
- **验证**：使用 SQLite 时可在应用内执行 `ActiveRecord::Base.connection.indexes("operation_logs")` 等确认；或运行下文「5. 可选：SQLite 索引验证任务」。

### 预期索引（SQLite）

| 表名 | 索引名 | 列 |
|------|--------|-----|
| operation_logs | index_operation_logs_on_account_id | (account_id) |
| operation_logs | index_operation_logs_on_account_id_and_created_at | (account_id, created_at) |
| operation_logs | index_operation_logs_on_action_and_created_at | (action, created_at) |
| operation_logs | index_operation_logs_on_board_id | (board_id) |
| operation_logs | index_operation_logs_on_board_id_and_created_at | (board_id, created_at) |
| operation_logs | index_operation_logs_on_subject_type_and_subject_id | (subject_type, subject_id) |
| operation_logs | index_operation_logs_on_user_id | (user_id) |
| sensitive_audit_logs | index_sensitive_audit_logs_on_account_id | (account_id) |
| sensitive_audit_logs | index_sensitive_audit_logs_on_account_id_and_created_at | (account_id, created_at) |
| sensitive_audit_logs | index_sensitive_audit_logs_on_action_and_created_at | (action, created_at) |
| sensitive_audit_logs | index_sensitive_audit_logs_on_subject_type_and_subject_id | (subject_type, subject_id) |
| sensitive_audit_logs | index_sensitive_audit_logs_on_user_id | (user_id) |

---

## 4. FTS5 与 search_records

- **当前**：单表 `search_records` + 虚拟表 `search_records_fts`（FTS5，`tokenize='porter'`）；应用层 `Search::Record::SQLite` 使用 FTS5 MATCH，并对 CJK 等无结果时回退到 LIKE 匹配 title/content。
- **建议**：
  - 保持现有 FTS5 + LIKE 回退即可，无需改动。
  - 若单表数据量极大（百万级行以上），可考虑应用层分表：按时间或 `account_id` 分表（SQLite 无原生分区，需在应用层维护多张 `search_records_*` 与对应 FTS5 表），或评估迁移到 MySQL 分片方案。

---

## 5. 可选：SQLite 索引验证任务

- 使用 SQLite 时运行 `bin/rails db:sqlite:check_indexes` 可验证 `operation_logs`、`sensitive_audit_logs` 及 `search_records`/FTS5 相关结构是否存在。
- 实现见 `buzzy/lib/tasks/sqlite_performance.rake`；非 SQLite 适配器时会自动跳过。

---

## 6. 相关文档

- **双适配器差异**：`docs/mysql-sqlite-differences.md`（WAL、schema、搜索分表/FTS5、迁移兼容）。
- **MySQL 性能**：`docs/mysql-performance-checklist.md`（索引、N+1、连接池、慢查询）。
- **部署与故障**：`docs/deployment.md`（如 SQLite「database disk image is malformed」处理）。
