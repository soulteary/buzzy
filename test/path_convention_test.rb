require "test_helper"

class PathConventionTest < ActiveSupport::TestCase
  FORBIDDEN_HELPERS = {
    /(?<!user_)board_cards_path\(/ => "board_cards_path(",
    /(?<!user_)board_involvement_path\(/ => "board_involvement_path(",
    /(?<!user_)board_entropy_path\(/ => "board_entropy_path(",
    /(?<!user_)column_left_position_path\(/ => "column_left_position_path(",
    /(?<!user_)column_right_position_path\(/ => "column_right_position_path(",
    /(?<!user_)columns_card_drops_stream_path\(/ => "columns_card_drops_stream_path(",
    /(?<!user_)columns_card_drops_not_now_path\(/ => "columns_card_drops_not_now_path(",
    /(?<!user_)columns_card_drops_closure_path\(/ => "columns_card_drops_closure_path(",
    /(?<!user_)columns_card_drops_column_path\(/ => "columns_card_drops_column_path("
  }.freeze

  TARGET_GLOBS = %w[
    app/views/**/*.erb
    app/helpers/**/*.rb
    app/controllers/**/*.rb
    app/javascript/**/*.js
    app/javascript/**/*.ts
  ].freeze

  test "app code uses user-scoped board/card path helpers" do
    offenders = []

    target_files.each do |path|
      content = File.read(path)
      FORBIDDEN_HELPERS.each do |regex, token|
        content.each_line.with_index(1) do |line, idx|
          next unless line.match?(regex)
          offenders << "#{relative(path)}:#{idx} includes #{token}"
        end
      end
    end

    assert offenders.empty?, <<~MSG
      Found non user-scoped path helper usage:
      #{offenders.join("\n")}
    MSG
  end

  private
    def target_files
      TARGET_GLOBS.flat_map { |glob| Dir.glob(Rails.root.join(glob)) }.uniq
    end

    def relative(path)
      Pathname.new(path).relative_path_from(Rails.root).to_s
    end
end
