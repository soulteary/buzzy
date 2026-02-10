class Cards::AssignmentsController < ApplicationController
  include CardScoped
  before_action :ensure_can_administer_card_assignments

  def new
    @assigned_to = @card.assignees.active.alphabetically.where.not(id: Current.user)
    @users = User.assignable_for_card(@card).alphabetically.where.not(id: @card.assignees).where.not(id: Current.user)
    # 分配列表随权限与账号用户变化，Turbo Frame 懒加载时 304 会导致只显示「我」；始终返回 200 与完整 body，不使用 fresh_when
  end

  def create
    target = User.assignable_for_card(@card).find(params[:assignee_id])
    # 允许：取消分配（目标已是 assignee）或 将目标加入分配（目标在可分配范围内）
    allowed = @card.assigned_to?(target) || User.assignable_for_card(@card).exists?(id: target.id)
    unless allowed
      return respond_to do |format|
        format.turbo_stream { head :forbidden }
        format.json { head :forbidden }
      end
    end
    if @card.toggle_assignment(target)
      respond_to do |format|
        format.turbo_stream
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.turbo_stream
        format.json { head :unprocessable_entity }
      end
    end
  end

  private
    def ensure_can_administer_card_assignments
      head :forbidden if Current.user.blank?
      head :forbidden unless Current.user.can_administer_card?(@card)
    end
end
