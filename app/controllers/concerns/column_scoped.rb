module ColumnScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_column
    before_action :ensure_board_editable, only: %i[ create update destroy ]
  end

  private
    # 列作用域：单用户账户用账号下列，否则用当前用户可访问列。当前不在「无当前用户」场景下开放列访问（如访客看公开看板）；若未来支持公开看板下列只读，需为 Current.user.blank? 增加只读作用域或提前 head :forbidden。
    def set_column
      @column = if Current.account_single_user? && Current.account.present?
        Column.joins(:board).where(boards: { account_id: Current.account.id }).find(params[:column_id])
      else
        Current.user.accessible_columns.find(params[:column_id])
      end
    end
end
