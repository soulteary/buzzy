require "test_helper"

class UuidMigrationConventionTest < ActiveSupport::TestCase
  MIGRATION_GLOB = Rails.root.join("db/migrate/*.rb").to_s
  LEGACY_MIGRATION_ALLOWLIST = %w[
    20251120110206_add_search_records.rb
  ].freeze
  NON_UUID_ID_COLUMNS_ALLOWLIST = %w[
    accounts.external_account_id
  ].freeze

  test "migrations keep uuid conventions for primary and foreign identifiers" do
    offenders = []

    migration_paths.each do |path|
      basename = File.basename(path)
      next if LEGACY_MIGRATION_ALLOWLIST.include?(basename)

      check_create_table_id_type(path, offenders)
      check_references_type(path, offenders)
      check_non_uuid_id_columns(path, offenders)
    end

    assert offenders.empty?, <<~MSG
      Found migration UUID convention violations:
      #{offenders.join("\n")}

      If this is truly intentional legacy behavior, add the migration filename to
      LEGACY_MIGRATION_ALLOWLIST or the specific column to NON_UUID_ID_COLUMNS_ALLOWLIST.
    MSG
  end

  private
    def migration_paths
      Dir.glob(MIGRATION_GLOB).sort
    end

    def check_create_table_id_type(path, offenders)
      File.readlines(path).each_with_index do |line, idx|
        stripped = line.strip
        next unless stripped.start_with?("create_table ")
        next if stripped.include?("id: false")
        next if stripped.include?("id: :uuid")

        offenders << "#{relative(path)}:#{idx + 1} create_table without id: :uuid"
      end
    end

    def check_references_type(path, offenders)
      File.readlines(path).each_with_index do |line, idx|
        stripped = line.strip
        next unless stripped.start_with?("t.references ") || stripped.start_with?("add_reference ")
        next if stripped.include?("type: :uuid")

        offenders << "#{relative(path)}:#{idx + 1} reference without type: :uuid"
      end
    end

    def check_non_uuid_id_columns(path, offenders)
      current_table = nil

      File.readlines(path).each_with_index do |line, idx|
        stripped = line.strip

        if (table_match = stripped.match(/\Acreate_table\s+["']?([a-zA-Z0-9_#\{\}]+)["']?/))
          current_table = table_match[1]
        elsif stripped == "end"
          current_table = nil
        end

        next unless stripped.match?(/\At\.(bigint|integer|string)\s+:[a-zA-Z_0-9]+_id\b/) ||
                    stripped.match?(/\A(add_column|change_column)\s+:[a-zA-Z_0-9]+,\s+:[a-zA-Z_0-9]+_id,\s+:(bigint|integer|string)\b/)

        table_name, column_name = extract_table_and_column(stripped, current_table)
        next if table_name.nil? || column_name.nil?

        full_name = "#{table_name}.#{column_name}"
        next if NON_UUID_ID_COLUMNS_ALLOWLIST.include?(full_name)

        offenders << "#{relative(path)}:#{idx + 1} #{full_name} uses non-uuid id column type"
      end
    end

    def extract_table_and_column(line, current_table)
      if (match = line.match(/\At\.(?:bigint|integer|string)\s+:([a-zA-Z_0-9]+_id)\b/))
        return [ current_table, match[1] ]
      end

      if (match = line.match(/\A(?:add_column|change_column)\s+:([a-zA-Z_0-9]+),\s+:([a-zA-Z_0-9]+_id),\s+:(?:bigint|integer|string)\b/))
        return [ match[1], match[2] ]
      end

      [ nil, nil ]
    end

    def relative(path)
      Pathname.new(path).relative_path_from(Rails.root).to_s
    end
end
