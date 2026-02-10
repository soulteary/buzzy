class Users::EventsController < ApplicationController
  include FilterScoped
  include UserAccountFromPath

  # 从「所有人的内容」进入其他用户页时 Current.user 可能为空，仍允许查看该用户动态
  skip_before_action :require_user_in_account, only: %i[ show ]
  allow_unauthorized_access only: %i[ show ]

  before_action :set_user, :set_filter, :set_user_filtering

  def show
    timeline_user = Current.user.present? ? Current.user : @user
    @filter = timeline_user.filters.new(creator_ids: [ @user.to_param ])
    visible_boards = boards_visible_when_viewing_user(@user)
    @day_timeline = timeline_user.timeline_for(day_param, filter: @filter, visible_boards: visible_boards)

    fresh_when @day_timeline
  end

  private
    def set_user
      @user = Current.account.users.active.find(params[:user_id])
    end

    def set_filter
      # 访客未加入该账户时用被查看用户构建仅含其动态的 filter
      timeline_user = Current.user.present? ? Current.user : @user
      @filter = timeline_user.filters.new(creator_ids: [ @user.to_param ])
    end

    def set_user_filtering
      return unless Current.user.present?
      @user_filtering = User::Filtering.new(Current.user, @filter, expanded: expanded_param)
    end

    def day_param
      if params[:day].present?
        Time.zone.parse(params[:day])
      else
        Time.current
      end
    end
end
