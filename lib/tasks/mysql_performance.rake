# frozen_string_literal: true

# MySQL 性能检查清单的可执行验证，见 docs/mysql-performance-checklist.md
namespace :db do
  namespace :mysql do
    desc "验证 MySQL 关键表与索引是否存在（events, operation_logs, sensitive_audit_logs, search_records_0..15）"
    task check_indexes: :environment do
      adapter = ActiveRecord::Base.connection.adapter_name
      unless adapter == "Trilogy" || adapter == "Mysql2"
        puts "跳过：当前适配器为 #{adapter}，仅 MySQL/Trilogy 执行本任务。"
        next
      end

      conn = ActiveRecord::Base.connection
      errors = []
      ok = []

      # 1. events
      if conn.table_exists?("events")
        expected = %w[
          index_events_on_account_id_and_action
          index_events_on_board_id_and_action_and_created_at
          index_events_on_board_id
          index_events_on_creator_id
          index_events_on_eventable
        ]
        existing = conn.indexes("events").map(&:name)
        missing = expected - existing
        if missing.any?
          errors << "events 缺少索引: #{missing.join(', ')}"
        else
          ok << "events: 5 个预期索引存在"
        end
      else
        errors << "表 events 不存在"
      end

      # 2. operation_logs
      if conn.table_exists?("operation_logs")
        expected = %w[
          index_operation_logs_on_account_id
          index_operation_logs_on_board_id
          index_operation_logs_on_user_id
          index_operation_logs_on_subject_type_and_subject_id
          index_operation_logs_on_account_id_and_created_at
          index_operation_logs_on_board_id_and_created_at
        ]
        existing = conn.indexes("operation_logs").map(&:name)
        missing = expected - existing
        if missing.any?
          errors << "operation_logs 缺少索引: #{missing.join(', ')}"
        else
          ok << "operation_logs: 预期复合索引存在"
        end
      else
        ok << "operation_logs: 表未创建（可选迁移未执行则正常）"
      end

      # 3. sensitive_audit_logs
      if conn.table_exists?("sensitive_audit_logs")
        expected = %w[
          index_sensitive_audit_logs_on_account_id
          index_sensitive_audit_logs_on_user_id
          index_sensitive_audit_logs_on_subject_type_and_subject_id
          index_sensitive_audit_logs_on_account_id_and_created_at
          index_sensitive_audit_logs_on_action_and_created_at
        ]
        existing = conn.indexes("sensitive_audit_logs").map(&:name)
        missing = expected - existing
        if missing.any?
          errors << "sensitive_audit_logs 缺少索引: #{missing.join(', ')}"
        else
          ok << "sensitive_audit_logs: 预期复合索引存在"
        end
      else
        ok << "sensitive_audit_logs: 表未创建（可选迁移未执行则正常）"
      end

      # 4. search_records_0..15
      search_shards_checked = 0
      search_shards_ok = 0
      16.times do |i|
        table = "search_records_#{i}"
        next unless conn.table_exists?(table)

        search_shards_checked += 1
        idx = conn.indexes(table)
        names = idx.map(&:name)
        has_account = names.any? { |n| n.to_s.include?("account_id") }
        has_ft = names.any? { |n| n.to_s.include?("account_key") && n.to_s.include?("content") }
        if has_account && (has_ft || idx.size >= 3)
          search_shards_ok += 1
        else
          errors << "#{table}: 缺少 account_id 或 FULLTEXT(account_key, content, title) 相关索引"
        end
      end
      ok << "search_records_0..15: #{search_shards_ok}/#{search_shards_checked} 张表索引检查通过" if search_shards_checked.positive? && search_shards_ok == search_shards_checked
      ok << "search_records_*: 未使用分表（仅 MySQL 且已跑 search 分表迁移时有）" if search_shards_checked.zero?

      # 5. operation_logs / cards / comments 可选索引（仅提示，不纳入失败）
      if conn.table_exists?("operation_logs")
        op_idx = conn.indexes("operation_logs").map(&:name)
        unless op_idx.include?("index_operation_logs_on_action_and_created_at")
          ok << "[可选] operation_logs 可加索引 (action, created_at)：见 db/migrate 20260211100002"
        end
      end
      if conn.table_exists?("cards")
        card_idx = conn.indexes("cards").map(&:name)
        unless card_idx.include?("index_cards_on_board_id_and_number")
          ok << "[可选] cards 可加索引 (board_id, number)：见 db/migrate 20260211100003"
        end
      end
      if conn.table_exists?("comments")
        comment_idx = conn.indexes("comments").map(&:name)
        unless comment_idx.include?("index_comments_on_card_id_and_created_at")
          ok << "[可选] comments 可加索引 (card_id, created_at)：见 db/migrate 20260211100004"
        end
      end

      # 输出
      ok.each { |msg| puts "  [OK] #{msg}" }
      errors.each { |msg| puts "  [ERR] #{msg}" }

      if errors.any?
        puts "\n请执行 bin/rails db:migrate 或对照 docs/mysql-performance-checklist.md 检查。"
        exit 1
      end

      puts "\nMySQL 索引检查通过。"
    end

    desc "输出 MySQL 慢查询日志开启命令（可复制到 MySQL 会话或 my.cnf）"
    task slow_query_log_help: [] do
      puts <<~TEXT
        # MySQL 慢查询日志（见 docs/mysql-performance-checklist.md 4.2）
        # 会话级（临时）：
        SET GLOBAL slow_query_log = 'ON';
        SET GLOBAL long_query_time = 2;
        SET GLOBAL slow_query_log_file = '/var/lib/mysql/slow.log';
        SET GLOBAL log_queries_not_using_indexes = 'ON';

        # 持久化请写入 my.cnf / mysqld 配置：
        # [mysqld]
        # slow_query_log = 1
        # long_query_time = 2
        # slow_query_log_file = /var/lib/mysql/slow.log
        # log_queries_not_using_indexes = 1
      TEXT
    end
  end
end
