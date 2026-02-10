# 卡片权限单一决策层：与控制器 ensure_* 及视图「可编辑/可删除/可分配」等判断保持一致，避免逻辑分散。
# Controller 与 view 通过 ApplicationController 的 helper_method 调用本类方法，传入当前请求上下文。
class CardPolicy
  class << self
    # 当前用户是否可编辑该卡片（同账号且非仅因提及/公开可访问）
    def editable?(user, card, board_accessed_via_mention:, super_admin: false)
      return false if card.blank?
      return true if super_admin
      user.present? && user.account_id == card.account_id && !board_accessed_via_mention
    end

    # 当前用户是否可见并使用删除卡片功能（创建者或账号管理员，且非仅因提及/公开可访问）
    def deletable?(user, card, board_accessed_via_mention:, super_admin: false)
      return false if card.blank?
      return true if super_admin
      user.present? && user.can_administer_card?(card) && !board_accessed_via_mention
    end

    # 是否允许当前身份将卡片 pin 到自己的界面
    def pinnable?(user, card, identity:, board_accessed_via_mention:, user_before_fallback: nil)
      return false if card.blank?
      requesting_user = user_before_fallback.presence || user
      return false if requesting_user.present? && requesting_user.account_id != card.account_id
      editable?(user, card, board_accessed_via_mention: board_accessed_via_mention) ||
        (board_accessed_via_mention && identity.present?)
    end

    # 当前用户是否属于其他账号（跨账号访问该卡片）
    def from_other_account?(user, card, super_admin: false)
      return false if super_admin
      card.present? && user.present? && user.account_id != card.account_id
    end

    # 卡片分配人（assignees）是否只读
    def assignees_read_only?(user, card, board_accessed_via_mention:, from_other_account:, viewing_other_user_as_limited_viewer:, super_admin: false)
      return true if card.blank?
      return false if super_admin
      user.blank? ||
        !user.can_administer_card?(card) ||
        board_accessed_via_mention ||
        from_other_account ||
        viewing_other_user_as_limited_viewer
    end
  end
end
