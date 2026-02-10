#!/usr/bin/env ruby

# One-off migration: convert existing action_text_rich_texts.body (HTML) to body_markdown.
# Run after adding body_markdown column. Keeps body unchanged for rollback.
#
# Run:
#   bin/rails runner script/migrations/html_to_markdown.rb --dry-run
#   bin/rails runner script/migrations/html_to_markdown.rb

require "optparse"

class HtmlToMarkdownMigration
  def initialize(dry_run:)
    @dry_run = dry_run
  end

  def run
    unless column_exists?
      puts "Column action_text_rich_texts.body_markdown not found. Run the migration first."
      return
    end

    scanned = 0
    updated = 0
    errors = 0

    ActionText::RichText.where.not(body: [ nil, "" ]).find_each do |rich_text|
      scanned += 1
      html = rich_text.body.to_s
      next if html.blank?

      markdown = HtmlToMarkdown.convert(html)
      next if markdown.blank? && rich_text.body_markdown.blank?

      if rich_text.body_markdown != markdown
        updated += 1
        puts " - #{rich_text.record_type}##{rich_text.record_id} (#{rich_text.name})"
        next if @dry_run

        rich_text.update_columns(body_markdown: markdown, updated_at: Time.current)
      end
    rescue StandardError => e
      errors += 1
      puts " - ERROR #{rich_text.record_type}##{rich_text.record_id}: #{e.message}"
    end

    puts "\nDone. scanned: #{scanned} updated: #{updated} errors: #{errors} mode: #{@dry_run ? 'dry-run' : 'apply'}"
  end

  private

  def column_exists?
    ActionText::RichText.column_names.include?("body_markdown")
  end
end

dry_run = false
OptionParser.new do |opts|
  opts.on("--dry-run") { dry_run = true }
end.parse!

HtmlToMarkdownMigration.new(dry_run: dry_run).run
