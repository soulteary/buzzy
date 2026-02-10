# frozen_string_literal: true

module Square
  # 我关注的人：展示当前用户关注的所有用户，可跳转到其主页。
  class FollowingController < ApplicationController
    skip_before_action :require_account, only: :index
    before_action :set_account_for_following

    def index
      # 仅展示仍活跃的被关注用户，已停用账号不展示
      @followed_users = Current.user.followed_users.merge(User.active).includes(:identity, :account).order(Arel.sql("lower(name)"))
    end

    private

      def set_account_for_following
        @account = Current.account.presence || Current.identity&.accounts&.active&.first
        if @account.present?
          Current.account = @account
          Current.user = Current.identity&.users&.find_by(account: @account)
        end
        redirect_to main_app.session_menu_path(script_name: nil) if @account.blank? || Current.user.blank?
      end
  end
end
