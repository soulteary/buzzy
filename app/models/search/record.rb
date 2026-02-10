class Search::Record < ApplicationRecord
  include const_get(connection.adapter_name)

  belongs_to :searchable, polymorphic: true
  belongs_to :card

  validates :account_id, :searchable_type, :searchable_id, :card_id, :board_id, :created_at, presence: true

  class << self
    def upsert!(attributes)
      record = find_by(searchable_type: attributes[:searchable_type], searchable_id: attributes[:searchable_id])
      if record
        record.update!(attributes)
        record
      else
        create!(attributes)
      end
    end

    def card_join
      "INNER JOIN #{table_name} ON #{table_name}.card_id = cards.id"
    end
  end

  scope :for_query, ->(query, user:, account_id: nil, board_ids: nil) do
    query = Search::Query.wrap(query)
    acc_id = account_id || user.account_id
    searchable_board_ids = user.searchable_account_board_ids[acc_id]
    bid_list = board_ids || searchable_board_ids || user.board_ids

    if query.valid? && bid_list.any?
      result = matching(query.to_s, acc_id).where(account_id: acc_id, board_id: bid_list)
      if result.limit(1).empty? && query.terms.present?
        result = matching_like(query.to_s).where(account_id: acc_id, board_id: bid_list)
      end
      result
    else
      none
    end
  end

  scope :search, ->(query, user:, account_id: nil, board_ids: nil) do
    query = Search::Query.wrap(query)
    base = for_query(query, user: user, account_id: account_id, board_ids: board_ids).joins(:card)
    base = base.merge(Card.kept) if Card.column_names.include?("deleted_at")
    base
      .includes(:searchable, card: [ :board, :creator ])
      .order(created_at: :desc)
      .select(:id, :account_id, :searchable_type, :searchable_id, :card_id, :board_id, :title, :content, :created_at, *search_fields(query))
  end

  # 搜索用户可见的所有内容：本账号下可访问看板 + 跨账号公开（all_access）看板；兼容分页
  def self.search_all_visible(query, user:)
    searchable = user.searchable_account_board_ids
    return Search::Record.none if searchable.empty?

    query = Search::Query.wrap(query)
    return Search::Record.none unless query.valid?

    # 仅本账号且无跨账号可见看板时走原单 relation，便于分页
    # 必须传入 board_ids：与 searchable_account_board_ids 一致，避免依赖 user.board_ids（accesses）为空导致搜不到
    if searchable.size == 1 && searchable.key?(user.account_id)
      rel = Search::Record.for(user.account_id).search(query, user: user, board_ids: searchable[user.account_id])
      # SQLite FTS5 / MySQL ngram 对部分 CJK 等可能无结果，回退到 LIKE 匹配 title/content
      if rel.limit(1).empty? && query.terms.present?
        rel = Search::Record.for(user.account_id).search_like(query, user: user, board_ids: searchable[user.account_id])
      end
      return rel
    end

    # 多账号：SQLite 单表可拼成一条 relation；Trilogy 分片需多查询合并后由调用方分页
    if connection.adapter_name == "SQLite"
      search_all_visible_sqlite(query, user: user, searchable: searchable)
    else
      search_all_visible_trilogy(query, user: user, searchable: searchable)
    end
  end

  def self.search_all_visible_sqlite(query, user:, searchable:)
    pairs = searchable.flat_map { |acc_id, bid_list| bid_list.map { |bid| [ acc_id, bid ] } }
    return none if pairs.empty?

    quoted = pairs.map { |(a, b)| "(#{table_name}.account_id = #{connection.quote(a)} AND #{table_name}.board_id = #{connection.quote(b)})" }.join(" OR ")
    rel = matching(query.to_s, user.account_id).where(quoted).joins(:card)
    rel = rel.merge(Card.kept) if Card.column_names.include?("deleted_at")
    rel = rel
      .includes(:searchable, card: [ :board, :creator ])
      .order(created_at: :desc)
      .select(:id, :account_id, :searchable_type, :searchable_id, :card_id, :board_id, :title, :content, :created_at, *search_fields(query))
    return rel unless rel.limit(1).empty? && query.terms.present?
    # FTS 无结果时（如 CJK）回退到 LIKE
    rel = matching_like(query.to_s).where(quoted).joins(:card)
    rel = rel.merge(Card.kept) if Card.column_names.include?("deleted_at")
    rel
      .includes(:searchable, card: [ :board, :creator ])
      .order(created_at: :desc)
      .select(:id, :account_id, :searchable_type, :searchable_id, :card_id, :board_id, :title, :content, :created_at, *search_fields(query))
  end

  # Trilogy 分片按账号分别查，合并后按时间倒序；返回数组，控制器需做分页（见 SearchesController）
  def self.search_all_visible_trilogy(query, user:, searchable:)
    max_merged = 500
    combined = searchable.flat_map do |acc_id, bid_list|
      next [] if bid_list.empty?
      Search::Record.for(acc_id).search(query, user: user, account_id: acc_id, board_ids: bid_list).limit(max_merged).to_a
    end
    # ngram 对部分 CJK 等可能无结果，回退到 LIKE
    if combined.empty? && query.terms.present?
      combined = searchable.flat_map do |acc_id, bid_list|
        next [] if bid_list.empty?
        Search::Record.for(acc_id).search_like(query, user: user, account_id: acc_id, board_ids: bid_list).limit(max_merged).to_a
      end
    end
    combined.uniq(&:id).sort_by { |r| -r.created_at.to_i }
  end

  def source
    searchable_type == "Comment" ? searchable : card
  end

  def comment
    searchable if searchable_type == "Comment"
  end
end
