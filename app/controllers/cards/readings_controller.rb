class Cards::ReadingsController < ApplicationController
  include CardScoped

  # Beacon 在卡片页 connect/visibilitychange 时用 JS 发 POST，Turbo 缓存可能导致页面内 meta csrf-token 过期，触发 422。
  # 仅标记当前用户已读，需登录且 card 在 URL 中，无 CSRF 放大风险，故跳过校验。
  skip_forgery_protection only: [ :create, :destroy ]

  skip_before_action :ensure_board_editable
  skip_before_action :ensure_not_mention_only_access

  def create
    @notifications = @card.read_by(Current.user)
    record_board_access
  end

  def destroy
    @notifications = @card.unread_by(Current.user)
    record_board_access
  end

  private
    def record_board_access
      @card.board.accessed_by(Current.user)
    end
end
