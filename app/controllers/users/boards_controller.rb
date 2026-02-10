# frozen_string_literal: true

class Users::BoardsController < ApplicationController
  include UserAccountFromPath

  skip_before_action :require_user_in_account, only: %i[ index ]
  before_action :set_user

  def index
    # 该用户在当前账号下可访问的看板；普通用户/访客展示「对所有人可见」及「已添加当前登录用户」的看板，本人或管理员可看全部（与 boards_visible_when_viewing_user 一致）
    base = (boards_visible_when_viewing_user(@user) || @user.boards).where(account_id: Current.account.id)
    @boards = base.alphabetically.includes(:creator)
    set_page_and_extract_portion_from @boards
  end

  private

    def set_user
      @user = Current.account.users.active.find(user_id_param)
    rescue ActiveRecord::RecordNotFound
      user = User.active.find_by(id: user_id_param)
      if user && Current.account.present? && user.account_id != Current.account.id
        redirect_to boards_user_path(user, script_name: nil) and return
      end
      raise
    end
end
