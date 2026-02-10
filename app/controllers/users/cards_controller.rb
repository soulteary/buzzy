# frozen_string_literal: true

class Users::CardsController < ApplicationController
  include UserAccountFromPath

  skip_before_action :require_user_in_account, only: %i[ index ]
  before_action :set_user

  def index
    # 重定向到卡片列表，筛选「指派给该用户」或「由该用户创建」的卡片
    redirect_to cards_path(
      assignee_ids: [ @user.to_param ],
      creator_ids: [ @user.to_param ],
      sorted_by: "newest"
    ), allow_other_host: false
  end

  private

    def set_user
      @user = Current.account.users.active.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      user = User.active.find_by(id: params[:id])
      if user && Current.account.present? && user.account_id != Current.account.id
        redirect_to cards_user_path(user, script_name: nil) and return
      end
      raise
    end
end
