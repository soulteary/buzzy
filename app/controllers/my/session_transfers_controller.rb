# frozen_string_literal: true

class My::SessionTransfersController < ApplicationController
  def update
    return head :not_found unless Buzzy.session_transfer_enabled?
    return head :not_found if forward_auth_enabled?

    enabled = ActiveModel::Type::Boolean.new.cast(session_transfer_params[:enabled])

    Current.identity.update!(session_transfer_enabled: enabled)

    respond_to do |format|
      format.html { redirect_back fallback_location: user_path(Current.user, script_name: nil) }
      format.json { head :no_content }
    end
  end

  private
    def session_transfer_params
      return params.expect(session_transfer: :enabled) if params[:session_transfer].present?

      { enabled: params.expect(:enabled) }
    end
end
