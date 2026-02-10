class Users::RolesController < ApplicationController
  include UserAccountFromPath

  before_action :forbid_in_single_user_account
  before_action :set_user
  before_action :ensure_permission_to_administer_user

  def update
    @user.update!(role_params)
    redirect_to account_settings_path
  end

  private
    def forbid_in_single_user_account
      redirect_to account_settings_path, notice: t("users.roles.not_applicable") if Current.account_single_user?
    end

    def set_user
      @user = Current.account.users.active.find(params[:user_id])
    end

    def ensure_permission_to_administer_user
      head :forbidden if Current.user.blank?
      head :forbidden unless Current.user.can_administer?(@user)
    end

    def role_params
      { role: params.require(:user)[:role].presence_in(%w[ member admin ]) || "member" }
    end
end
