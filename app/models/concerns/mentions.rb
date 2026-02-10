module Mentions
  extend ActiveSupport::Concern
  PLAIN_TEXT_MENTION_REGEX = /(?<![\p{L}\p{N}._-])@([\p{L}\p{N}._-]+)/u
  MARKDOWN_MENTION_TOKEN_REGEX = /\[@[^\]]*\]\((\d+|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|[a-zA-Z0-9._+-]+)\)/i

  included do
    has_many :mentions, as: :source, dependent: :destroy
    has_many :mentionees, through: :mentions
    after_save_commit :create_mentions_later, if: :should_create_mentions?
  end

  def create_mentions(mentioner: Current.user)
    mentionees = scan_mentionees.uniq
    mentionee_ids = mentionees.map(&:id)
    existing_mentions = mentions.to_a
    existing_by_mentionee_id = existing_mentions.index_by(&:mentionee_id)

    added_mentionees = mentionees.reject { |mentionee| existing_by_mentionee_id.key?(mentionee.id) }
    removed_mentions = existing_mentions.reject { |mention| mentionee_ids.include?(mention.mentionee_id) }

    Mention.transaction do
      added_mentionees.each do |mentionee|
        mentionee.mentioned_by mentioner, at: self
      end

      removed_mentions.each(&:destroy!)
    end

    track_mention_events(
      mentioner: mentioner,
      added_mentionees: added_mentionees,
      removed_mentions: removed_mentions
    )
  end

  def mentionable_content
    rich_text_associations.filter_map do |association|
      rich_text = send(association.name)
      next if rich_text.blank?

      mention_safe_plain_text(rich_text)
    end.join(" ")
  end

  private
    # Build plain text with robust mention resolution.
    # ActionText::RichText#to_plain_text only resolves via sgid; if sgid is invalid
    # but gid is still valid, it degrades to "Unknown user". We normalize mention
    # nodes first so notification excerpts keep real usernames.
    def mention_safe_plain_text(rich_text)
      body = rich_text.body
      html = if body.respond_to?(:fragment) && body.fragment.present?
        body.fragment.to_html
      elsif body.respond_to?(:to_html)
        body.to_html
      else
        body.to_s
      end
      return rich_text.to_plain_text if html.blank?

      fragment = Nokogiri::HTML.fragment(html)
      changed = false
      fragment.css("action-text-attachment").each do |node|
        next unless mention_node?(node)

        user = ActionText::MentionResolver.resolve_user(node)
        replacement = if user.present?
          user.attachable_plain_text_representation
        else
          node.content.to_s.presence || I18n.t("users.missing_attachable_label", default: "Unknown user")
        end
        node.replace(Nokogiri::XML::Text.new(replacement, fragment))
        changed = true
      end

      return rich_text.to_plain_text unless changed

      ActionText::Content.new(fragment.to_html).to_plain_text
    rescue Nokogiri::XML::SyntaxError
      rich_text.to_plain_text
    end

    def mention_node?(node)
      content_type = node["content-type"].to_s
      return true if content_type.downcase.include?("mention")

      ActionText::MentionResolver.resolve_user(node).present?
    end

    def scan_mentionees
      (mentionees_from_attachments + mentionees_from_markdown_tokens + mentionees_from_plain_text).uniq & mentionable_users
    end

    def mentionees_from_attachments
      rich_text_associations.flat_map do |association|
        body = send(association.name)&.body
        next [] unless body

        body.attachments.filter_map do |attachment|
          if mention_attachment?(attachment)
            ActionText::MentionResolver.resolve_user(attachment.node)
          else
            attachment.attachable
          end
        end
      end.compact.select { |a| a.is_a?(User) }
    end

    # Support plain "@handle" mentions typed directly in markdown/text.
    # This keeps mention notifications working even when users don't pick from prompt menu.
    def mentionees_from_plain_text
      handles = mentionable_content.to_s.scan(PLAIN_TEXT_MENTION_REGEX).flatten.map { |h| h.to_s.downcase }.uniq
      return [] if handles.empty?

      handles.filter_map do |handle|
        ActionText::MentionResolver.resolve_user({ "handle" => handle })
      end
    end

    # Parse markdown mention tokens directly from stored body_markdown.
    # This is a robust fallback when some attachment nodes lose resolvable ids.
    def mentionees_from_markdown_tokens
      tokens = rich_text_associations.flat_map do |association|
        rich_text = send(association.name)
        markdown = rich_text.respond_to?(:body_markdown) ? rich_text.body_markdown.to_s : ""
        next [] if markdown.blank?

        markdown.scan(MARKDOWN_MENTION_TOKEN_REGEX).flatten
      end.map { |token| token.to_s.downcase }.uniq
      return [] if tokens.empty?

      tokens.filter_map do |token|
        ActionText::MentionResolver.resolve_user({ "handle" => token, "user_id" => token, "id" => token, "data-handle" => token })
      end
    end

    def mention_attachment?(attachment)
      node = attachment.node
      return false if node.blank?

      content_type = node["content-type"].to_s
      return true if content_type.downcase.include?("mention")

      ActionText::MentionResolver.resolve_user(node).present?
    end

    def mentionable_users
      board.users
    end

    def rich_text_associations
      self.class.reflect_on_all_associations(:has_one).filter { it.klass == ActionText::RichText }
    end

    def should_create_mentions?
      mentionable? && (mentionable_content_changed? || should_check_mentions?)
    end

    def mentionable_content_changed?
      rich_text_associations.any? { send(it.name)&.body_previously_changed? }
    end

    def create_mentions_later
      Mention::CreateJob.perform_later(self, mentioner: Current.user)
    end

    def track_mention_events(mentioner:, added_mentionees:, removed_mentions:)
      return unless respond_to?(:track_event)

      added_mentionee_ids = added_mentionees.map(&:id)
      removed_mentionee_ids = removed_mentions.map(&:mentionee_id)

      if added_mentionee_ids.any?
        track_event("mentioned", creator: mentioner, mentionee_ids: added_mentionee_ids)
      end

      if removed_mentionee_ids.any?
        track_event("unmentioned", creator: mentioner, mentionee_ids: removed_mentionee_ids)
      end
    end

    # Template method
    def mentionable?
      true
    end

    def should_check_mentions?
      false
    end
end
