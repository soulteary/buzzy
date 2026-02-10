class SessionsController < ApplicationController
  disallow_account_scope
  require_unauthenticated_access except: :destroy
  rate_limit to: 10, within: 3.minutes, only: :create, with: :rate_limit_exceeded

  layout "public"

  def new
    if forward_auth_enabled?
      if forward_auth_trusted_request?
        redirect_to root_path(script_name: nil)
      else
        render plain: "Forward Auth is enabled. Please access through the trusted gateway.", status: :unauthorized
      end
      return
    end
  end

  def create
    if forward_auth_enabled?
      if forward_auth_trusted_request?
        redirect_to root_path(script_name: nil)
      else
        respond_to do |format|
          format.html { render plain: "Forward Auth is enabled. Please access through the trusted gateway.", status: :unauthorized }
          format.json { render json: { message: "Forward Auth request is not trusted" }, status: :unauthorized }
        end
      end
      return
    end

    if identity = Identity.find_by(email_address: email_address)
      sign_in identity
    elsif Account.accepting_signups?
      sign_up
    else
      redirect_to_fake_session_magic_link email_address
    end
  end

  def destroy
    if forward_auth_enabled?
      respond_to do |format|
        format.html { redirect_back fallback_location: root_path(script_name: nil), allow_other_host: false }
        format.json { head :not_found }
      end
      return
    end

    terminate_session

    respond_to do |format|
      format.html { redirect_to_logout_url }
      format.json { head :no_content }
    end
  end

  private
    def forward_auth_enabled?
      cfg = Rails.application.config.forward_auth
      cfg.is_a?(ForwardAuth::Config) && cfg.enabled?
    end

    def forward_auth_trusted_request?
      cfg = Rails.application.config.forward_auth
      cfg.is_a?(ForwardAuth::Config) && cfg.trusted?(request)
    end

    def magic_link_from_sign_in_or_sign_up
      if identity = Identity.find_by_email_address(email_address)
        identity.send_magic_link
      else
        signup = Signup.new(email_address: email_address)
        signup.create_identity if signup.valid?(:identity_creation) && Account.accepting_signups?
      end
    end

    def email_address
      params.expect(:email_address)
    end

    def rate_limit_exceeded
      rate_limit_exceeded_message = I18n.t("sessions.rate_limit")

      respond_to do |format|
        format.html { redirect_to new_session_path, alert: rate_limit_exceeded_message }
        format.json { render json: { message: rate_limit_exceeded_message }, status: :too_many_requests }
      end
    end

    def sign_in(identity)
      redirect_to_session_magic_link identity.send_magic_link
    end

    def sign_up
      signup = Signup.new(email_address: email_address)

      if signup.valid?(:identity_creation)
        magic_link = signup.create_identity
        redirect_to_session_magic_link magic_link
      else
        respond_to do |format|
        format.html { redirect_to new_session_path, alert: I18n.t("sessions.something_went_wrong") }
        format.json { render json: { message: I18n.t("sessions.something_went_wrong") }, status: :unprocessable_entity }
        end
      end
    end
end
