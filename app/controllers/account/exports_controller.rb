class Account::ExportsController < ApplicationController
  before_action :ensure_export_enabled
  before_action :ensure_admin_or_owner
  before_action :ensure_export_limit_not_exceeded, only: :create
  before_action :set_export, only: :show

  CURRENT_EXPORT_LIMIT = 10

  def show
  end

  def create
    export = Current.account.exports.create!(user: Current.user)
    SensitiveAuditLog.log!(action: "account_export_started", account: Current.account, user: Current.user, subject: export)
    export.build_later
    redirect_to account_settings_path, notice: I18n.t("account.export_started")
  end

  private
    def ensure_export_enabled
      head :not_found unless Buzzy.export_data_enabled?
    end

    def ensure_admin_or_owner
      head :forbidden if Current.user.blank?
      head :forbidden unless Current.user.admin? || Current.user.owner?
    end

    def ensure_export_limit_not_exceeded
      head :too_many_requests if Current.account.exports.current.count >= CURRENT_EXPORT_LIMIT
    end

    def set_export
      @export = Current.account.exports.completed.find_by(id: params[:id], user: Current.user)
    end
end
