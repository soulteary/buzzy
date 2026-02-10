# MySQL 与 SQLite 差异与对齐

> 双适配器（Trilogy/MySQL 与 SQLite3）已支持，本文档列出实现差异、配置要点及迁移兼容规则，便于 CI/本地双环境与生产 MySQL 行为一致。

## 1. 配置与加载

| 项 | 说明 |
|----|------|
| **入口** | `config/database.yml` 根据 `Buzzy.db_adapter` 加载对应配置文件，不直接定义连接。 |
| **适配器** | `Buzzy.db_adapter` 由 `ENV["DATABASE_ADAPTER"]` 决定，默认 `"sqlite"`。见 `lib/buzzy.rb`。 |
| **MySQL** | 加载 `config/database.mysql.yml`（adapter: trilogy，utf8mb4，pool: 50 等）。 |
| **SQLite** | 加载 `config/database.sqlite.yml`（adapter: sqlite3），并指定 `schema_dump: schema_sqlite.rb`。 |

因此：

- **MySQL 环境**：`db/schema.rb` 由 `bin/rails db:schema:dump` 生成（默认 schema 文件名）。
- **SQLite 环境**：`db/schema_sqlite.rb` 由 dump 生成，避免与 MySQL 的 schema.rb 互相覆盖。

CI 中通过矩阵（如 `.github/workflows/test.yml`）同时跑 `DATABASE_ADAPTER=sqlite` 与 `DATABASE_ADAPTER=mysql`。

---

## 2. 主要功能差异与对齐

### 2.1 UUID 主键与类型

- **实现**：`config/initializers/uuid_primary_keys.rb`
- **MySQL (Trilogy)**：UUID 存为 `binary(16)`，`MysqlUuidAdapter` 识别并映射为 `:uuid`，SchemaDumper 输出 `id: :uuid`。
- **SQLite**：UUID 存为 `blob(16)`，`SqliteUuidAdapter` 识别并映射为 `:uuid`。
- **迁移写法**：统一使用 `id: :uuid`、`t.uuid :xxx`、`t.references :yyy, type: :uuid`，两种适配器均支持，无需分叉。

### 2.2 字符串与文本长度

- **实现**：`config/initializers/table_definition_column_limits.rb`
- **MySQL**：`string` 默认 limit 255（VARCHAR）；`text` 支持 `size: :tiny/:medium/:long` 或默认 65535（TEXT）。
- **SQLite**：本身不强制 VARCHAR/TEXT 长度；通过 `SQLiteColumnLimitCheckConstraints` 在列上添加 CHECK 约束（按字符/字节）模拟限制，保证与 MySQL 行为对齐。

迁移中继续使用 `t.string`、`t.text`（及可选的 `size: :long` 等）即可，两适配器通用。

### 2.3 WAL（仅 SQLite）

- **实现**：`config/initializers/sqlite_wal.rb`
- **行为**：仅在 `Rails.env.production?` 且当前为 sqlite3 连接时执行 `PRAGMA journal_mode=WAL`，降低多进程写同一库时的损坏风险。
- **MySQL**：无此逻辑，按服务端配置即可。

### 2.4 Schema 文件

| 适配器 | Schema 文件 | 配置来源 |
|--------|-------------|----------|
| MySQL  | `db/schema.rb` | 默认，或 database.mysql.yml 未改 schema_dump 时 |
| SQLite | `db/schema_sqlite.rb` | `config/database.sqlite.yml` 中 `schema_dump: schema_sqlite.rb` |

注意：

- 使用 MySQL 时执行 `bin/rails db:schema:dump` 只更新 `schema.rb`。
- 使用 SQLite 时执行 `bin/rails db:schema:dump` 只更新 `schema_sqlite.rb`。
- 两文件版本号应一致（与最新迁移版本对应）；若在某一适配器上跑完新迁移，需在该适配器下再执行一次 `db:schema:dump`，否则另一适配器的 schema 文件会落后。

---

## 3. 搜索：MySQL 与 SQLite 实现差异

### 3.1 表结构

| 项 | MySQL (Trilogy) | SQLite |
|----|------------------|--------|
| **表** | 16 张分表：`search_records_0` … `search_records_15`（由迁移创建） | 单表 `search_records` |
| **全文索引** | 每分表上 FULLTEXT 索引，后改为 ngram 解析器（CJK） | FTS5 虚拟表 `search_records_fts`（porter 分词） |
| **account_key** | 有列 `account_key` 并参与 FULLTEXT | 无此列（FTS5 仅 title/content） |

### 3.2 迁移分工

- **仅 MySQL**（迁移内已 `return if connection.adapter_name == "SQLite"`）：
  - `20251112093037_create_search_indices.rb`：创建 16 张 `search_index_*`（后由 create_search_record_shards 删除）。
  - `20251113190256_create_search_record_shards.rb`：创建 16 张 `search_records_*`，带 FULLTEXT。
  - `20251121092508_add_account_key_to_search_records.rb`：为 16 张分表加 `account_key` 与 FULLTEXT。
  - `20251121112416_remove_old_fulltext_indexes_from_search_records.rb`：移除旧 FULLTEXT 索引。
  - `20260207100000_use_ngram_fulltext_for_search_records.rb`：将 FULLTEXT 改为 ngram 解析器。
- **仅 SQLite**（迁移内已 `return unless connection.adapter_name == "SQLite"`）：
  - `20251120110206_add_search_records.rb`：创建单表 `search_records` 与 FTS5 虚拟表 `search_records_fts`。

其余搜索相关迁移（如 drop_search_results、drop search_index 等）按上述分工只会在对应适配器上执行，不会在另一适配器上操作不存在的表。

### 3.3 应用层行为

- **MySQL**：`Search::Record::Trilogy`，按 account 分片查询，使用 ngram FULLTEXT；CJK 由 ngram 支持。
- **SQLite**：`Search::Record::SQLite`，单表 + FTS5 MATCH，Porter 词干；对 CJK 等 FTS 无结果时，有 **CJK/LIKE 回退**（`matching_like`），按 title/content LIKE 匹配。
- 两适配器在「无全文结果时回退到 LIKE」的逻辑在 `Search::Record.search_all_visible` 等处已统一处理。

---

## 4. 迁移兼容性总览

### 4.1 双适配器均可运行的迁移（通用）

以下迁移使用 `id: :uuid`、`t.references type: :uuid`、`t.string`/`t.text` 等通用定义，**不写死 MySQL 专有语法**（如 `FULLTEXT`、`charset`、`WITH PARSER ngram`），在 MySQL 与 SQLite 上都会执行：

- `20260210120000_create_operation_logs.rb`
- `20260210120001_rename_operation_logs_changes_to_details.rb`
- `20260210120002_rename_operation_logs_changes_to_payload.rb`
- `20260210130000_create_sensitive_audit_logs.rb`
- `20260210130001_add_soft_delete_to_cards_boards_accounts.rb`
- 以及更早的 operation_logs / sensitive_audit_logs / deleted_at 以外的所有业务表迁移（accounts、boards、cards、comments、events、identities 等）。

编写**新迁移**时请勿使用：

- `type: :fulltext`、`ADD FULLTEXT ... WITH PARSER ngram`（仅 MySQL）
- `charset` / `collation`（仅 MySQL）
- `execute "CREATE VIRTUAL TABLE ... fts5(...)"`（仅 SQLite，且应放在「仅 SQLite」分支内）

若必须使用适配器专有语法，请在迁移内用 `connection.adapter_name == "SQLite"` 或 `!= "SQLite"` 判断并 `return`，避免在另一适配器上执行导致报错。

### 4.2 仅 MySQL 的迁移（已做 adapter 判断）

| 迁移 | 说明 |
|------|------|
| `create_search_indices` | 创建 16 张 search_index_*，含 fulltext；内部 `return if connection.adapter_name == "SQLite"` |
| `create_search_record_shards` | 创建 16 张 search_records_* 并 drop search_index_*；内部 `return if connection.adapter_name == "SQLite"` |
| `add_account_key_to_search_records` | 为 16 张分表加 account_key 与 fulltext；内部 `return if connection.adapter_name == "SQLite"` |
| `remove_old_fulltext_indexes_from_search_records` | 移除旧 fulltext 索引；内部 `return if connection.adapter_name == "SQLite"` |
| `use_ngram_fulltext_for_search_records` | FULLTEXT 改为 ngram；内部 `return if connection.adapter_name == "SQLite"` |
| `add_optional_index_events_account_id_created_at` | 可选索引；内部 `return if connection.adapter_name == "SQLite"` |
| `add_optional_index_operation_logs_action_created_at` | 可选索引；**双适配器执行**（与 MySQL 索引对齐，见 docs/sqlite-performance.md） |
| `add_optional_index_cards_board_id_and_number` | 可选索引；内部 `return if connection.adapter_name == "SQLite"` |
| `add_optional_index_comments_card_id_and_created_at` | 可选索引；内部 `return if connection.adapter_name == "SQLite"` |

以上除 `add_optional_index_operation_logs_action_created_at` 外，在 CI 或本地使用 SQLite 时会被跳过，不会报错。

### 4.3 仅 SQLite 的迁移（已做 adapter 判断）

| 迁移 | 说明 |
|------|------|
| `add_search_records` | 创建单表 search_records 与 FTS5 虚拟表；内部 `return unless connection.adapter_name == "SQLite"` |

---

## 5. SQLite schema 与 deleted_at / operation_logs / sensitive_audit_logs

- **operation_logs**、**sensitive_audit_logs**、以及 **cards / boards / accounts** 的 **deleted_at**（及 deleted_by_id）由上述通用迁移创建，在 SQLite 上跑完 `bin/rails db:migrate` 后，应**重新 dump** 以更新 `db/schema_sqlite.rb`：
  - `DATABASE_ADAPTER=sqlite bin/rails db:migrate`
  - `DATABASE_ADAPTER=sqlite bin/rails db:schema:dump`
- 这样 `schema_sqlite.rb` 会包含 operation_logs、sensitive_audit_logs、以及 cards/boards/accounts 的 deleted_at/deleted_by_id 与索引，与 MySQL 的 schema.rb 在语义上一致（表结构对齐，索引名可能因适配器略有差异）。

若未在 SQLite 上跑完最新迁移就 dump，`schema_sqlite.rb` 的 version 会落后，且缺少这些表/列，加载 schema 时会与迁移不一致。

当前 `db/schema.rb` 与 `db/schema_sqlite.rb` 已按上述迁移手动同步至版本 `2026_02_11_100004`（含 operation_logs、sensitive_audit_logs、cards/boards/accounts 的 deleted_at）。之后在新迁移合并后，建议在对应适配器下执行 `db:migrate` 再 `db:schema:dump` 以保持两文件与库一致。

---

## 6. 其他说明与遗漏检查

### 6.1 initial_schema 与 charset/collation

- `20251111122540_initial_schema.rb` 中所有 `create_table` 均带 `charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci"`，为 MySQL 专有选项。
- Rails 的 SQLite3 适配器会**忽略**不支持的选项，因此该迁移在 SQLite 上运行不会报错，双适配器均可执行。
- 新迁移应避免在「双适配器通用」路径下使用 `charset`/`collation`；若仅针对 MySQL，请用 `return if connection.adapter_name == "SQLite"` 包住整段或使用 adapter 分支。

### 6.2 add_unique_index_to_card_activity_spikes（部分 MySQL 专有）

- `20251120203100_add_unique_index_to_card_activity_spikes_on_card_id.rb` 中，仅 **DELETE 重复行的 execute**（MySQL 语法的 `DELETE s1 FROM ... INNER JOIN`）被包在 `if connection.adapter_name != "SQLite"` 内，在 SQLite 上不执行。
- **remove_index + add_index unique** 在两种适配器上都会执行，故 card_activity_spikes(card_id) 的唯一索引在 MySQL 与 SQLite 上均存在，行为一致。

### 6.3 Rake 任务（MySQL 专用任务已做适配器判断）

- `lib/tasks/mysql_performance.rake` 中 `db:mysql:check_indexes`、`db:mysql:slow_query_log_help` 等会先判断 `connection.adapter_name == "Trilogy" || adapter == "Mysql2"`，非 MySQL 时直接跳过并输出提示，不会在 SQLite 下执行 MySQL 专有逻辑。
- 其他与 DB 相关的 Rake 若依赖 MySQL 专有功能，也应在任务开头做同样判断。

### 6.4 测试与脚本中的适配器判断

- `test/test_helpers/search_test_helper.rb`、`test/models/comment/searchable_test.rb`、`test/models/card/searchable_test.rb` 等已按 `connection.adapter_name == "SQLite"` 区分 FTS5 与分片搜索的断言或数据准备，无需改动。
- `script/migrations/reset_*_ids.rb` 等脚本中涉及 SQLite 序列或 MySQL 自增时，已按需区分实现。

### 6.5 应用代码中勿写死 adapter

- 在模型或应用代码中需要按当前数据库序列化/类型转换时，不要写死 `ActiveRecord::Type.lookup(:uuid, adapter: :trilogy)`，否则在 SQLite 下可能行为不一致。
- 应使用当前连接判断后再 lookup，例如：`uuid_adapter = (connection.adapter_name == "SQLite" ? :sqlite3 : :trilogy); ActiveRecord::Type.lookup(:uuid, adapter: uuid_adapter)`。参见已修复的 `app/models/board/accessible.rb` 中 `notifications_for_user`。

---

## 7. 小结

| 主题 | MySQL | SQLite | 对齐方式 |
|------|--------|--------|----------|
| 配置 | database.mysql.yml | database.sqlite.yml，schema_dump: schema_sqlite.rb | Buzzy.db_adapter + database.yml 按需加载 |
| UUID | binary(16) + MysqlUuidAdapter | blob(16) + SqliteUuidAdapter | 迁移统一用 id: :uuid / t.uuid |
| 字符串长度 | VARCHAR/TEXT 原生 | CHECK 约束 | TableDefinitionColumnLimits + SQLiteColumnLimitCheckConstraints |
| WAL | — | production 下 PRAGMA journal_mode=WAL | sqlite_wal.rb |
| Schema 文件 | schema.rb | schema_sqlite.rb | 各环境 dump 后提交，版本号与迁移一致 |
| 搜索 | 16 分表 + FULLTEXT ngram | 单表 + FTS5 + CJK/LIKE 回退 | 迁移内 adapter 判断，应用层 Search::Record 分 Trilogy/SQLite |
| 仅 MySQL 迁移 | 执行 | 跳过（return if SQLite） | 已在迁移内判断，避免 CI/本地 SQLite 报错 |
| 仅 SQLite 迁移 | 跳过 | 执行 | add_search_records 内 return unless SQLite |

新增迁移时：**避免写死 MySQL 或 SQLite 专有语法**；若必须使用，用 `connection.adapter_name` 判断并在另一适配器上直接 `return`，以保证双适配器下迁移均可安全运行。

**遗漏检查清单（已核对）：**

- [x] 仅 MySQL 的迁移均含 `return if connection.adapter_name == "SQLite"`（搜索分表、ngram、可选索引等）。
- [x] 仅 SQLite 的迁移含 `return unless connection.adapter_name == "SQLite"`（add_search_records）。
- [x] initial_schema 的 charset/collation 在 SQLite 上被忽略，双适配器可跑。
- [x] add_unique_index_to_card_activity_spikes 仅 DELETE 步骤为 MySQL 专有，索引在双适配器均添加。
- [x] db:mysql:* Rake 任务已判断适配器，SQLite 下跳过。
- [x] schema.rb 与 schema_sqlite.rb 已同步至 2026_02_11_100004，含 operation_logs、sensitive_audit_logs、deleted_at。
- [x] 应用代码中无写死 `adapter: :trilogy` 的 UUID 类型 lookup（board/accessible 已改为按 connection.adapter_name 判断）。
