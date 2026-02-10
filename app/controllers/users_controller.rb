class UsersController < ApplicationController
  include UserAccountFromPath

  # 查看其他用户资料时可能不在其账号下，允许 Current.user 为空（如从「所有人的内容」进入其他用户页）
  skip_before_action :require_user_in_account, only: %i[ show profile ]
  allow_unauthorized_access only: %i[ show profile ]

  before_action :set_user, except: %i[ index follow unfollow ]
  before_action :set_user_for_follow, only: %i[ follow unfollow ] # 使用 user_id 参数，避免路径中的 users/:id 导致 Current.account 被设为被关注用户所在账号
  before_action :ensure_permission_to_change_user, only: %i[ update destroy ]

  def follow
    if Current.user.following?(@user)
      redirect_to user_path(@user, script_name: nil), notice: t("users.follow.already_following")
    elsif Current.user == @user
      redirect_to user_path(@user, script_name: nil), alert: t("users.follow.cannot_follow_self")
    else
      Current.user.user_follows.create!(followee: @user)
      redirect_to user_path(@user, script_name: nil), notice: t("users.follow.followed")
    end
  rescue ActiveRecord::RecordInvalid
    # 并发或重复提交时可能触发唯一约束
    redirect_to user_path(@user, script_name: nil), notice: t("users.follow.already_following")
  end

  def unfollow
    Current.user.user_follows.where(followee: @user).destroy_all
    redirect_back fallback_location: user_path(@user, script_name: nil), notice: t("users.follow.unfollowed")
  end

  def index
    respond_to do |format|
      format.html { redirect_to user_path(Current.user, script_name: nil) }
      format.json { set_page_and_extract_portion_from Current.account.users.active.alphabetically.includes(:identity) }
    end
  end

  def show
  end

  def profile
    return unless @user.verified?

    timeline_user = Current.user.present? ? Current.user : @user
    @filter = timeline_user.filters.new(creator_ids: [ @user.to_param ])
    visible_boards = boards_visible_when_viewing_user(@user)
    @day_timeline = timeline_user.timeline_for(profile_day_param, filter: @filter, visible_boards: visible_boards)
  end

  def edit
  end

  def update
    if @user.update(user_params)
      respond_to do |format|
        format.html { redirect_to profile_user_path(@user, script_name: nil) }
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    # Single user per account: do not allow deactivating the only real user
    if Current.account.users.active.where.not(role: :system).one? && @user == Current.user
      respond_to do |format|
        format.html { redirect_to account_settings_path, alert: t("users.destroy.single_user_not_allowed") }
        format.json { render json: { error: t("users.destroy.single_user_not_allowed") }, status: :unprocessable_entity }
      end
      return
    end

    @user.deactivate
    SensitiveAuditLog.log!(action: "user_deactivated", account: Current.account, user: Current.user, subject: @user)

    respond_to do |format|
      format.html { redirect_to account_settings_path }
      format.json { head :no_content }
    end
  end

  private
    def set_user
      @user = Current.account.users.active.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      user = User.active.find_by(id: params[:id])
      if user && Current.account.present? && user.account_id != Current.account.id
        # 带账号前缀访问时，若用户属于其他账号则重定向到无前缀的 /users/:id 或 /users/:id/profile
        profile_path = request.path_parameters[:action] == "profile" ? profile_user_path(user, script_name: nil) : user_path(user, script_name: nil)
        redirect_to profile_path and return
      end
      raise
    end

    def ensure_permission_to_change_user
      head :forbidden if Current.user.blank?
      head :forbidden unless Current.user.can_change?(@user)
    end

    def user_params
      params.expect(user: [ :name, :avatar, :bio ])
    end

    def profile_day_param
      if params[:day].present?
        Time.zone.parse(params[:day])
      else
        Time.current
      end
    end

    def set_user_for_follow
      @user = User.active.find(params[:user_id])
    rescue ActiveRecord::RecordNotFound
      redirect_to main_app.session_menu_path(script_name: nil), alert: t("users.follow.user_not_found")
    end
end
