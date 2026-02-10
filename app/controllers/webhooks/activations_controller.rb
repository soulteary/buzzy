class Webhooks::ActivationsController < ApplicationController
  include BoardScoped

  before_action :ensure_permission_to_admin_board

  def create
    webhook = @board.webhooks.find(params[:webhook_id])
    webhook.activate

    redirect_to webhook
  end

  private
end
