# frozen_string_literal: true

# 当访问 /users/:id（无账号前缀）时，根据被查看用户设置 Current.account，
# 使 require_account 通过且后续逻辑能正确取到当前账号与当前用户。
module UserAccountFromPath
  extend ActiveSupport::Concern

  included do
    prepend_before_action :set_account_from_viewed_user, if: :user_path_request?
  end

  private

    def user_path_request?
      # follow/unfollow 时不能按被关注用户设 Current.account，否则当前用户不在该账号下会导致 Current.user 为空并重定向到 session menu
      return false if %w[ follow unfollow ].include?(action_name)
      Current.account.nil? && user_id_param.present?
    end

    def user_id_param
      params[:id] || params[:user_id]
    end

    def set_account_from_viewed_user
      user = User.active.find_by(id: user_id_param)
      return unless user

      Current.account = user.account
      Current.user = Current.identity&.users&.find_by(account: Current.account)
    end
end
