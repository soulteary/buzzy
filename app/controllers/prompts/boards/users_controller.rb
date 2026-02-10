class Prompts::Boards::UsersController < ApplicationController
  include BoardScoped

  def index
    # @提及候选统一使用全局活跃用户，支持跨账号提及
    @users = User.active.alphabetically

    if stale? etag: @users
      render layout: false
    end
  end
end
