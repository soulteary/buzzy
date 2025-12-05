class Sessions::MagicLinksController < ApplicationController
  disallow_account_scope
  require_unauthenticated_access
  rate_limit to: 10, within: 15.minutes, only: :create, with: -> { redirect_to session_magic_link_path, alert: "Wait 15 minutes, then try again" }

  layout "public"

  def show
  end

  def create
    if magic_link = MagicLink.consume(code)
      start_new_session_for magic_link.identity
      redirect_to after_sign_in_url(magic_link)
    else
      redirect_to session_magic_link_path, flash: { shake: true }
    end
  end

  private
    def code
      params.expect(:code)
    end

    def after_sign_in_url(magic_link)
      if magic_link.for_sign_up?
        new_signup_completion_path
      else
        after_authentication_url
      end
    end
end
