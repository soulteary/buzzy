class Accounts::UsersController < ApplicationController
  before_action :set_user, only: %i[ destroy ]

  def index
    @users = Current.account.users.active
  end

  def destroy
    @user.deactivate
    redirect_to users_url
  end

  private
    def set_user
      @user = Current.account.users.active.find(params[:id])
    end
end
