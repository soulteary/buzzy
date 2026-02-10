module User::Searcher
  extend ActiveSupport::Concern

  included do
    has_many :search_queries, class_name: "Search::Query", dependent: :destroy
  end

  # 账号下可访问的看板 + 跨账号具备可见性（公开 all_access）的看板，用于搜索范围
  # 单用户：本账号全部看板；多用户：有权限的看板 + 本账号内公开（all_access）看板，保证「该用户可见的所有内容」都可被搜索
  # 返回 Hash[account_id => [board_id, ...]]
  def searchable_account_board_ids
    own_ids = if account_single_user?
      account.boards.pluck(:id)
    else
      (board_ids + account.boards.all_access.pluck(:id)).uniq
    end
    own = { account_id => own_ids }
    return own.reject { |_, ids| ids.empty? } if own_ids.empty?

    other_account_ids = Account.active.where.not(id: account_id).pluck(:id)
    return own if other_account_ids.empty?

    pairs = Board.where(account_id: other_account_ids).all_access.pluck(:account_id, :id)
    others = pairs.group_by(&:first).transform_values { |list| list.map(&:second) }
    own.merge(others).reject { |_, ids| ids.empty? }
  end

  def search(terms)
    Search::Record.search_all_visible(terms, user: self)
  end

  def remember_search(terms)
    search_queries.find_or_create_by(terms: terms).tap do |search_query|
      search_query.touch unless search_query.invalid? || search_query.previously_new_record?
    end
  end
end
