class Sessions::TransfersController < ApplicationController
  disallow_account_scope
  require_unauthenticated_access

  before_action :reject_session_transfer_when_forward_auth

  def show
    @identity = Identity.find_by_transfer_id(params[:id])
    @session_transfer_available = @identity.present?
  end

  def update
    if identity = Identity.find_by_transfer_id(params[:id])
      start_new_session_for identity
      redirect_to session_menu_path(script_name: nil)
    else
      head :bad_request
    end
  end

  private
    def reject_session_transfer_when_forward_auth
      head :not_found if forward_auth_enabled?
    end
end
