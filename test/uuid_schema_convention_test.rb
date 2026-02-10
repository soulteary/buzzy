require "test_helper"

class UuidSchemaConventionTest < ActiveSupport::TestCase
  SCHEMA_PATH = Rails.root.join("db/schema.rb")
  NON_UUID_ID_COLUMNS_ALLOWLIST = %w[
    accounts.external_account_id
  ].freeze

  test "schema uses uuid for primary keys and *_id columns" do
    schema = File.read(SCHEMA_PATH)
    failures = []

    each_table_block(schema) do |table_name, table_header, body|
      unless table_header.include?("id: false")
        unless table_header.include?("id: :uuid")
          failures << "#{table_name}.id is not uuid"
        end
      end

      body.each_line do |line|
        match = line.match(/^\s*t\.(\w+)\s+"([^"]+)"/)
        next unless match

        column_type = match[1]
        column_name = match[2]
        next unless column_name.end_with?("_id")

        full_name = "#{table_name}.#{column_name}"
        next if NON_UUID_ID_COLUMNS_ALLOWLIST.include?(full_name)
        next if column_type == "uuid"

        failures << "#{full_name} should be uuid, got #{column_type}"
      end
    end

    assert failures.empty?, <<~MSG
      Found non-UUID id columns in schema:
      #{failures.join("\n")}

      If this column is intentional (business sequence/non-foreign identifier),
      add it to NON_UUID_ID_COLUMNS_ALLOWLIST in #{self.class.name}.
    MSG
  end

  private
    def each_table_block(schema)
      current_table = nil
      current_header = nil
      current_body = +""

      schema.each_line do |line|
        if current_table.nil?
          table_match = line.match(/^\s*create_table\s+"([^"]+)",\s*(.+)\s+do\s+\|t\|/)
          next unless table_match

          current_table = table_match[1]
          current_header = table_match[2]
          current_body = +""
        elsif line.match?(/^\s*end\s*$/)
          yield(current_table, current_header, current_body)
          current_table = nil
          current_header = nil
          current_body = +""
        else
          current_body << line
        end
      end
    end
end
