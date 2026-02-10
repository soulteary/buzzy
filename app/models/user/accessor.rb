module User::Accessor
  extend ActiveSupport::Concern

  included do
    has_many :accesses, dependent: :destroy
    has_many :boards, through: :accesses
    has_many :accessible_columns, through: :boards, source: :columns
    has_many :accessible_cards, through: :boards, source: :cards
    has_many :accessible_comments, through: :accessible_cards, source: :comments

    after_create_commit :grant_access_to_boards, unless: :system?
  end

  # 下拉菜单展示的看板：当前账户有权限的看板 + 跨账户公开（all_access）且创建者已被当前用户关注的看板
  # 单用户账户内直接用 account.boards，避免 accesses 查询
  def boards_visible_in_dropdown
    own = if account.users.active.where.not(role: :system).one?
      account.boards.alphabetically.to_a
    else
      boards.ordered_by_recently_accessed.to_a
    end
    followed_ids = followed_user_ids
    return own if followed_ids.empty?
    cross = Board.where(all_access: true, creator_id: followed_ids).where.not(account_id: account_id).alphabetically.to_a
    (own + cross).uniq
  end

  # 因被卡片或卡片下评论 @ 提及而可访问的卡片（用于隐藏看板下被提及用户打开卡片并参与讨论）
  def cards_accessible_via_mention(account = nil)
    card_ids_from_cards = mentions.where(source_type: "Card").select(:source_id)
    card_ids_from_comments = mentions.where(source_type: "Comment")
      .joins("INNER JOIN comments ON comments.id = mentions.source_id")
      .select("comments.card_id")
    scope = Card.where(id: card_ids_from_cards).or(Card.where(id: card_ids_from_comments)).distinct
    scope = scope.where(account_id: account.id) if account.present?
    scope
  end

  # 因被指派而可访问的卡片（仅开放该卡片，不扩展到整看板）
  def cards_accessible_via_assignment(account = nil)
    scope = Card.joins(:assignments).where(assignments: { assignee_id: id }).distinct
    scope = scope.where(account_id: account.id) if account.present?
    scope
  end

  # 在某看板内仅因 @ 提及或指派而可见的卡片集合（用于非公开看板的受限视图，不包含通过 Access 的完整看板权限）
  def cards_visible_in_board_for_limited_view(board)
    return Card.none if board.blank?
    account_scope = board.account
    mention_ids = cards_accessible_via_mention(account_scope).where(board_id: board.id).distinct.pluck(:id)
    assignment_ids = cards_accessible_via_assignment(account_scope).where(board_id: board.id).distinct.pluck(:id)
    Card.where(id: mention_ids | assignment_ids)
  end

  # 是否曾收到过该卡片的提及类通知（用于无 Mention 记录的旧数据或其它通知来源时的访问回退）
  def notified_of_card?(card)
    return false if card.blank?
    notifications
      .where(source_type: "Mention")
      .joins("INNER JOIN mentions ON mentions.id = notifications.source_id")
      .where(
        "(mentions.source_type = 'Card' AND mentions.source_id = :card_id) OR (mentions.source_type = 'Comment' AND mentions.source_id IN (SELECT id FROM comments WHERE card_id = :card_id))",
        card_id: card.id
      )
      .exists?
  end

  def draft_new_card_in(board)
    board.cards.find_or_initialize_by(creator: self, status: "drafted").tap do |card|
      card.update!(created_at: Time.current, updated_at: Time.current, last_active_at: Time.current)
    end
  end

  private
    def grant_access_to_boards
      Access.insert_all account.boards.all_access.ids.collect { |board_id| { id: ActiveRecord::Type::Uuid.generate, board_id: board_id, user_id: id, account_id: account.id } }
    end
end
