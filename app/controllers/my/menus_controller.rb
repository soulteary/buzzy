class My::MenusController < ApplicationController
  def show
    @filters = Current.user.filters.all
    @boards = super_admin? ? Current.account.boards.alphabetically : Current.user.boards_visible_in_dropdown
    @tags = Current.account.tags.all.alphabetically
    # 下拉「用户」展示当前用户关注的、仍活跃的用户（不含自己），便于快速跳转
    @users = Current.user.present? ? Current.user.followed_users.merge(User.active).includes(:identity, :account).order(Arel.sql("lower(name)")) : User.none
    @people_section_title = t("my.menus.people_following")
    @accounts = Current.identity.accounts.active

    # Turbo Frame 收到 304 时响应体为空，会用空内容替换 frame 导致下拉菜单显示为空，故仅对非 frame 请求做条件响应
    fresh_when etag: [ @filters, @boards, @tags, @users, @accounts, super_admin? ] unless turbo_frame_request?
  end
end
