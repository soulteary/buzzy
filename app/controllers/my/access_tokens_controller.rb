class My::AccessTokensController < ApplicationController
  SHOW_TOKEN_EXPIRY = 10.seconds

  def index
    @access_tokens = my_access_tokens.order(created_at: :desc)
  end

  def show
    @access_token = Identity::AccessTokenShowToken.find_access_token_by_show_token_id(params[:id])
    unless @access_token && my_access_tokens.include?(@access_token)
      redirect_to my_access_tokens_path, alert: I18n.t("users.access_tokens.token_no_longer_visible") and return
    end
  end

  def new
    @access_token = my_access_tokens.new
  end

  def create
    access_token = my_access_tokens.create!(access_token_params)
    show_token = Identity::AccessTokenShowToken.create!(
      access_token: access_token,
      expires_at: SHOW_TOKEN_EXPIRY.from_now
    )
    redirect_to my_access_token_path(show_token.id)
  end

  def destroy
    my_access_tokens.find(params[:id]).destroy!
    redirect_to my_access_tokens_path
  end

  private
    def my_access_tokens
      Current.identity.access_tokens
    end

    def access_token_params
      params.expect(access_token: %i[ description permission ])
    end
end
