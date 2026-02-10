# frozen_string_literal: true

# SQLite 性能检查：索引与 FTS5 验证，见 docs/sqlite-performance.md
namespace :db do
  namespace :sqlite do
    desc "验证 SQLite 关键表与索引（operation_logs, sensitive_audit_logs, search_records/FTS5）"
    task check_indexes: :environment do
      adapter = ActiveRecord::Base.connection.adapter_name
      unless adapter == "SQLite"
        puts "跳过：当前适配器为 #{adapter}，仅 SQLite 执行本任务。"
        next
      end

      conn = ActiveRecord::Base.connection
      errors = []
      ok = []

      # 1. operation_logs
      if conn.table_exists?("operation_logs")
        expected = %w[
          index_operation_logs_on_account_id
          index_operation_logs_on_account_id_and_created_at
          index_operation_logs_on_action_and_created_at
          index_operation_logs_on_board_id
          index_operation_logs_on_board_id_and_created_at
          index_operation_logs_on_subject_type_and_subject_id
          index_operation_logs_on_user_id
        ]
        existing = conn.indexes("operation_logs").map(&:name)
        missing = expected - existing
        if missing.any?
          errors << "operation_logs 缺少索引: #{missing.join(', ')}"
        else
          ok << "operation_logs: 预期索引存在"
        end
      else
        ok << "operation_logs: 表未创建（可选）"
      end

      # 2. sensitive_audit_logs
      if conn.table_exists?("sensitive_audit_logs")
        expected = %w[
          index_sensitive_audit_logs_on_account_id
          index_sensitive_audit_logs_on_account_id_and_created_at
          index_sensitive_audit_logs_on_action_and_created_at
          index_sensitive_audit_logs_on_subject_type_and_subject_id
          index_sensitive_audit_logs_on_user_id
        ]
        existing = conn.indexes("sensitive_audit_logs").map(&:name)
        missing = expected - existing
        if missing.any?
          errors << "sensitive_audit_logs 缺少索引: #{missing.join(', ')}"
        else
          ok << "sensitive_audit_logs: 预期索引存在"
        end
      else
        ok << "sensitive_audit_logs: 表未创建（可选）"
      end

      # 3. search_records + FTS5
      if conn.table_exists?("search_records")
        idx = conn.indexes("search_records").map(&:name)
        has_account = idx.any? { |n| n.to_s.include?("account_id") }
        has_searchable = idx.any? { |n| n.to_s.include?("searchable_type") && n.to_s.include?("searchable_id") }
        if has_account && has_searchable
          ok << "search_records: 表与索引存在"
        else
          errors << "search_records: 缺少 account_id 或 (searchable_type, searchable_id) 索引"
        end
        if conn.table_exists?("search_records_fts")
          ok << "search_records_fts: FTS5 虚拟表存在"
        else
          errors << "search_records_fts: FTS5 虚拟表不存在"
        end
      else
        ok << "search_records: 未使用（仅 SQLite 单表搜索时有）"
      end

      ok.each { |msg| puts "  [OK] #{msg}" }
      errors.each { |msg| puts "  [ERR] #{msg}" }

      if errors.any?
        puts "\n请执行 bin/rails db:migrate 或对照 docs/sqlite-performance.md 检查。"
        exit 1
      end

      puts "\nSQLite 索引检查通过。"
    end
  end
end
