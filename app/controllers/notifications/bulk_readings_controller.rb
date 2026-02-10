class Notifications::BulkReadingsController < ApplicationController
  def create
    Current.user.notifications.unread.read_all

    respond_to do |format|
      format.html do
        if from_tray?
          # Turbo Frame 期望响应包含 id="notifications" 的 frame，否则会报错并忽略响应
          @notifications = Current.user.notifications.none
          render "notifications/trays/show", layout: false, status: :ok
        else
          redirect_to notifications_path
        end
      end
      format.json { head :no_content }
    end
  end

  private
    def from_tray?
      params[:from_tray]
    end
end
