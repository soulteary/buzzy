class UsersController < ApplicationController
  require_unauthenticated_access

  before_action :set_account_from_join_code

  def new
    @user = User.new
  end

  def create
    @user = @account.users.create!(user_params)
    start_new_session_for @user
    redirect_to root_url
  end

  private
    def set_account_from_join_code
      @account = Account.find_by_join_code!(params[:join_code])
    end

    def user_params
      params.require(:user).permit(:name, :email_address, :password)
    end
end
