#!/usr/bin/env ruby

# One-off maintenance script:
# - normalize mention nodes (gid/sgid/content)
# - preserve gid fallback for non-mention attachments
# - fill missing sgid from gid when possible
#
# Run locally:
#   bin/rails runner script/migrations/backfill-action-text-mentions.rb --dry-run
#   bin/rails runner script/migrations/backfill-action-text-mentions.rb
#
# Run in container:
#   docker compose exec app bin/rails runner script/migrations/backfill-action-text-mentions.rb --dry-run

require "optparse"
require "cgi"

class BackfillActionTextMentions
  MENTION_CONTENT_TYPE = "application/vnd.actiontext.mention"

  attr_reader :dry_run

  def initialize(dry_run:)
    @dry_run = dry_run
  end

  def run
    scanned = 0
    changed = 0

    scope.find_each do |rich_text|
      scanned += 1
      next if rich_text.body.blank?

      updated_html = normalize_html(rich_text.body.to_html)
      next if updated_html.nil?

      changed += 1
      puts " - update #{rich_text.record_type}##{rich_text.record_id} (#{rich_text.name})"
      next if dry_run

      rich_text.update_columns(body: updated_html, updated_at: Time.current)
    end

    puts "\nBackfill finished"
    puts "  scanned: #{scanned}"
    puts "  changed: #{changed}"
    puts "  mode: #{dry_run ? 'dry-run' : 'apply'}"
  end

  private
    def scope
      ActionText::RichText.where("body LIKE '%action-text-attachment%'")
    end

    def normalize_html(html)
      fragment = Nokogiri::HTML.fragment(html)
      changed = false

      fragment.css("action-text-attachment").each do |node|
        changed |= ensure_sgid_from_gid(node)
        changed |= normalize_mention_node(node)
      end

      changed ? fragment.to_html : nil
    end

    def ensure_sgid_from_gid(node)
      return false if node["sgid"].present? || node["gid"].blank?

      gid = GlobalID.parse(node["gid"])
      return false unless gid

      record = gid.find
      return false unless record.respond_to?(:attachable_sgid)

      node["sgid"] = record.attachable_sgid
      true
    rescue ActiveRecord::RecordNotFound, GlobalID::IdentificationError, URI::InvalidURIError
      false
    end

    def normalize_mention_node(node)
      return false unless mention_node?(node)

      raw_content = node["content"].to_s
      changed = false

      if node["gid"].present? && node["sgid"].blank?
        gid = GlobalID.parse(node["gid"]) rescue nil
        if gid
          user = gid.find rescue nil
          if user&.respond_to?(:attachable_sgid)
            node["sgid"] = user.attachable_sgid
            changed = true
          end
        end
      end

      node.remove_attribute("content")

      user = ActionText::MentionResolver.resolve_user(node)
      user ||= infer_user_from_content(raw_content)

      if user
        node["gid"] = user.to_global_id.to_s if node["gid"].blank?
        node["sgid"] = user.attachable_sgid if node["sgid"].blank?
        node.content = user.attachable_plain_text_representation
      else
        node.content = I18n.t("users.missing_attachable_label", default: "Unknown user")
      end

      true
    end

    def mention_node?(node)
      return true if node["content-type"].to_s.downcase.include?("mention")
      ActionText::MentionResolver.resolve_user(node).present?
    end

    def infer_user_from_content(raw)
      return nil if raw.blank?

      decoded = CGI.unescapeHTML(raw).to_s.strip
      decoded = decoded.sub(/\A"/, "").sub(/"\z/, "").strip
      return nil if decoded.blank?

      fragment = Nokogiri::HTML.fragment(decoded)
      src = fragment.at_css("img")&.[]("src").to_s
      return nil if src.blank?

      user_id = src[%r{\/users\/([^\/]+)\/avatar}, 1]
      return nil if user_id.blank?

      User.unscoped.find_by(id: user_id)
    rescue Nokogiri::XML::SyntaxError, ArgumentError
      nil
    end
end

options = { dry_run: false }

OptionParser.new do |opts|
  opts.banner = "Usage: bin/rails runner #{__FILE__} [options]"
  opts.on("--dry-run", "Only print changes without writing DB") { options[:dry_run] = true }
  opts.on("-h", "--help", "Show help") do
    puts opts
    exit
  end
end.parse!

BackfillActionTextMentions.new(dry_run: options[:dry_run]).run
