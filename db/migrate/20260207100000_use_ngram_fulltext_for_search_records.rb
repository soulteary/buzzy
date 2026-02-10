# frozen_string_literal: true

class UseNgramFulltextForSearchRecords < ActiveRecord::Migration[8.2]
  def up
    return if connection.adapter_name == "SQLite"

    # MySQL 默认 FULLTEXT 按空格分词，中文无空格导致搜不到。使用 ngram 解析器支持 CJK。
    16.times do |shard_id|
      table_name = "search_records_#{shard_id}"
      index_name = "index_search_records_#{shard_id}_on_account_key_and_content_and_title"

      remove_index table_name, name: index_name, type: :fulltext, if_exists: true
      execute <<-SQL.squish
        ALTER TABLE #{connection.quote_table_name(table_name)}
        ADD FULLTEXT INDEX #{connection.quote_column_name(index_name)} (account_key, content, title) WITH PARSER ngram
      SQL
    end
  end

  def down
    return if connection.adapter_name == "SQLite"

    16.times do |shard_id|
      table_name = "search_records_#{shard_id}"
      index_name = "index_search_records_#{shard_id}_on_account_key_and_content_and_title"

      execute "ALTER TABLE #{connection.quote_table_name(table_name)} DROP INDEX #{connection.quote_column_name(index_name)}"
      add_index table_name, [:account_key, :content, :title], name: index_name, type: :fulltext
    end
  end
end
