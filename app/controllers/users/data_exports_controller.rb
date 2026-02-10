class Users::DataExportsController < ApplicationController
  include UserAccountFromPath

  before_action :ensure_export_enabled
  before_action :set_user
  before_action :ensure_current_user
  before_action :ensure_export_limit_not_exceeded, only: :create
  before_action :set_export, only: :show

  CURRENT_EXPORT_LIMIT = 10

  def show
  end

  def create
    @user.data_exports.create!(account: Current.account).build_later
    redirect_to user_path(@user, script_name: nil), notice: I18n.t("users.data_exports.export_started")
  end

  private
    def ensure_export_enabled
      head :not_found unless Buzzy.export_data_enabled?
    end

    def set_user
      @user = Current.account.users.find(params[:user_id])
    end

    def ensure_current_user
      head :forbidden if Current.user.blank?
      head :forbidden unless @user == Current.user
    end

    def ensure_export_limit_not_exceeded
      head :too_many_requests if @user.data_exports.current.count >= CURRENT_EXPORT_LIMIT
    end

    def set_export
      @export = @user.data_exports.completed.find_by(id: params[:id])
    end
end
