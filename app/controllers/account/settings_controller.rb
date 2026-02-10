class Account::SettingsController < ApplicationController
  before_action :set_account

  def show
    @user = Current.user
  end

  private
    def set_account
      @account = Current.account
    end
end
