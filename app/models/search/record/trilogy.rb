module Search::Record::Trilogy
  extend ActiveSupport::Concern

  SHARD_COUNT = 16

  included do
    self.abstract_class = true
    before_save :set_account_key, :stem_content

    scope :matching, ->(query, account_id) do
      # ngram: do not insert space between CJK so MATCH tokenization matches stored content
      full_query = "+account#{account_id} +(#{Search::Stemmer.stem_for_ngram(query)})"
      where("MATCH(#{table_name}.account_key, #{table_name}.content, #{table_name}.title) AGAINST(? IN BOOLEAN MODE)", full_query)
    end

    # ngram 对部分 CJK 或短词可能无结果时，用 LIKE 回退：按原文匹配 title/content（加表前缀避免 JOIN 时列歧义）
    scope :matching_like, ->(query) {
      return none if query.blank?
      pattern = "%#{Search::Record.sanitize_sql_like(query.to_s)}%"
      where("(#{table_name}.title LIKE :pat OR #{table_name}.content LIKE :pat)", pat: pattern)
    }

    SHARD_CLASSES = SHARD_COUNT.times.map do |shard_id|
      Class.new(self) do
        self.table_name = "search_records_#{shard_id}"

        def self.name
          "Search::Record"
        end
      end
    end.freeze
  end

  class_methods do
    def shard_id_for_account(account_id)
      Zlib.crc32(account_id.to_s) % SHARD_COUNT
    end

    def search_fields(query)
      "#{connection.quote(query.terms)} AS query"
    end

    def for(account_id)
      SHARD_CLASSES[shard_id_for_account(account_id)]
    end

    # 与 search 相同结构，但用 LIKE 匹配而非 ngram FULLTEXT，供 FULLTEXT 无结果时回退（如部分 CJK）
    def search_like(query, user:, account_id: nil, board_ids: nil)
      q = Search::Query.wrap(query)
      acc_id = account_id || user.account_id
      bid_list = board_ids || user.board_ids
      return none unless q.valid? && bid_list.any?

      matching_like(q.to_s)
        .where(account_id: acc_id, board_id: bid_list)
        .joins(:card)
        .includes(:searchable, card: [ :board, :creator ])
        .order(created_at: :desc)
        .select(:id, :account_id, :searchable_type, :searchable_id, :card_id, :board_id, :title, :content, :created_at, search_fields(q))
    end
  end

  def card_title
    highlight(card.title, show: :full) if card_id
  end

  def card_description
    highlight(card.description.to_plain_text, show: :snippet) if card_id
  end

  def comment_body
    highlight(comment.body.to_plain_text, show: :snippet) if comment
  end

  private
    def stem_content
      # MySQL ngram: store without CJK space so ngram index tokens match search query
      self.title = Search::Stemmer.stem_for_ngram(title) if title_changed?
      self.content = Search::Stemmer.stem_for_ngram(content) if content_changed?
    end

    def set_account_key
      self.account_key = "account#{account_id}"
    end

    def highlight(text, show:)
      if text.present? && attribute?(:query)
        highlighter = Search::Highlighter.new(query)
        show == :snippet ? highlighter.snippet(text) : highlighter.highlight(text)
      else
        text
      end
    end
end
