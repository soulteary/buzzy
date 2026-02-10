# frozen_string_literal: true

module Admin
  class UsersController < ApplicationController
    # 冻结/解冻可能在被操作用户所在账户的 URL 下请求（script_name=该账户），当前身份在该账户下无 User，需跳过否则会 302 到 session/menu
    skip_before_action :require_user_in_account
    allow_unauthorized_access

    before_action :require_super_admin
    before_action :set_user

    def freeze
      if @user == Current.user
        redirect_to admin_all_content_path(script_name: admin_redirect_script_name), alert: I18n.t("admin.users.cannot_freeze_self")
        return
      end
      @user.update!(active: false, frozen_at: Time.current, frozen_by: Current.user)
      redirect_to admin_all_content_path(script_name: admin_redirect_script_name), notice: I18n.t("admin.users.frozen")
    end

    def unfreeze
      @user.update!(active: true, frozen_at: nil, frozen_by: nil)
      redirect_to admin_all_content_path(script_name: admin_redirect_script_name), notice: I18n.t("admin.users.unfrozen")
    end

    private

      def set_user
        @user = User.find(params[:id])
      end

      # 重定向到无 account 前缀的管理页，由 set_account_from_identity_when_single 设置 Current.account/Current.user，避免 302 到 session/menu
      def admin_redirect_script_name
        nil
      end
  end
end
