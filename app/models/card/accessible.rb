module Card::Accessible
  extend ActiveSupport::Concern

  # 看板权限或仅因 @ 提及可访问（跨账号评论者）均可查看卡片及附件（如评论中的图片）
  def accessible_to?(user)
    return false if user.blank?
    board.accessible_to?(user) ||
      # 跨账号查看「所有人可见」看板时，允许读取该看板下已发布卡片附件（如背景图放大）。
      (board.all_access? && published?) ||
      user.cards_accessible_via_mention(board.account).exists?(id: id) ||
      user.cards_accessible_via_assignment(board.account).exists?(id: id) ||
      user.notified_of_card?(self)
  end

  def publicly_accessible?
    published? && board.publicly_accessible?
  end

  def clean_inaccessible_data
    accessible_user_ids = board.accesses.pluck(:user_id)
    pins.where.not(user_id: accessible_user_ids).in_batches.destroy_all
    watches.where.not(user_id: accessible_user_ids).in_batches.destroy_all
  end

  private
    def grant_access_to_assignees
      board.accesses.grant_to(assignees)
    end

    def clean_inaccessible_data_later
      Card::CleanInaccessibleDataJob.perform_later(self)
    end
end
