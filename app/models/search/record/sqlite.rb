module Search::Record::SQLite
  extend ActiveSupport::Concern

  included do
    attribute :result_title, :string
    attribute :result_content, :string
    attribute :query, :string

    has_one :search_records_fts, -> { with_rowid },
      class_name: "Search::Record::SQLite::Fts", foreign_key: :rowid, primary_key: :id, dependent: :destroy

    after_save :upsert_to_fts5_table

    # FTS table stores stemmed content; use stemmed query for MATCH (supports CJK tokenization)
    scope :matching, ->(query, account_id) { joins(:search_records_fts).where("search_records_fts MATCH ?", Search::Stemmer.stem(query)) }

    # 当 FTS5（porter 分词）对 CJK 等无结果时，用 LIKE 回退：按原文匹配 title/content
    scope :matching_like, ->(query) {
      return none if query.blank?
      pattern = "%#{Search::Record.sanitize_sql_like(query.to_s)}%"
      where("(title LIKE :pat OR content LIKE :pat)", pat: pattern)
    }
  end

  class_methods do
    # 与 search 相同结构，但用 LIKE 匹配而非 FTS，供 FTS 无结果时回退（如中文「卡片」）
    def search_like(query, user:, account_id: nil, board_ids: nil)
      q = Search::Query.wrap(query)
      acc_id = account_id || user.account_id
      bid_list = board_ids || user.board_ids
      return none unless q.valid? && bid_list.any?

      base = matching_like(q.to_s).where(account_id: acc_id, board_id: bid_list).joins(:card)
      base = base.merge(Card.kept) if Card.column_names.include?("deleted_at")
      base
        .includes(:searchable, card: [ :board, :creator ])
        .order(created_at: :desc)
        .select(:id, :account_id, :searchable_type, :searchable_id, :card_id, :board_id, :title, :content, :created_at, *search_fields(q))
    end
    # Return only query for Ruby-side highlighting; main table has original title/content, FTS has stemmed
    def search_fields(query)
      [ "#{connection.quote(query.terms)} AS query" ]
    end

    def for(account_id)
      self
    end
  end

  def card_title
    text = result_title.presence || title || card.title
    highlight_original(text)
  end

  def card_description
    highlight_original(result_content.presence || content, snippet: true) unless comment
  end

  def comment_body
    highlight_original(result_content.presence || content, snippet: true) if comment
  end

  private
    def highlight_original(text, snippet: false)
      return nil unless text.present?
      return escape_highlight_marks(text) unless query.present?

      highlighter = Search::Highlighter.new(query)
      result = snippet ? highlighter.snippet(text) : highlighter.highlight(text)
      escape_highlight_marks(result)
    end

    def escape_highlight_marks(html)
      return nil unless html.present?

      CGI.escapeHTML(html)
        .gsub(CGI.escapeHTML(Search::Highlighter::OPENING_MARK), Search::Highlighter::OPENING_MARK)
        .gsub(CGI.escapeHTML(Search::Highlighter::CLOSING_MARK), Search::Highlighter::CLOSING_MARK)
        .html_safe
    end

    # Store stemmed content in FTS so MATCH works for both English (porter) and CJK (space-separated chars)
    def upsert_to_fts5_table
      Fts.upsert(id, Search::Stemmer.stem(title), Search::Stemmer.stem(content))
    end
end
