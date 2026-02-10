# frozen_string_literal: true

# 「所有人的内容」与「管理所有内容」共用的用户列表逻辑：按账户分组，可选排除当前用户。
# 在 controller 中 set @users_by_account，供视图按账户展示用户列表。
module AllContentUsersList
  extend ActiveSupport::Concern

  private

    # 设置 @users_by_account（按 account_id 分组的用户列表）。
    # admin: true 时使用管理用范围（含已冻结），否则仅活跃用户。
    # exclude_current: true 时从各组中排除当前用户（与「所有人的内容」行为一致）。
    def set_users_by_account_for_all_content(admin: false, exclude_current: true)
      scope = User.scope_for_all_content(admin: admin)
      @users_by_account = User.grouped_by_account(scope)
      exclude_current_user_from_grouped!(@users_by_account) if exclude_current && Current.user.present?
    end

    # 从按 account_id 分组的 Hash 中，从每组里移除当前用户（原地修改）。
    def exclude_current_user_from_grouped!(grouped_hash)
      return if grouped_hash.blank? || Current.user.blank?
      current_user_id = Current.user.id
      grouped_hash.transform_values! { |list| list.reject { |u| u.id == current_user_id } }
    end
end
