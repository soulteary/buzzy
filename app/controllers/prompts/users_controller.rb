class Prompts::UsersController < ApplicationController
  def index
    # 全局用户提及：不限制当前 account
    @users = User.active.alphabetically

    if stale? etag: @users
      render layout: false
    end
  end
end
