class EventsController < ApplicationController
  include DayTimelinesScoped

  before_action :redirect_to_current_user_when_in_account, only: :index

  def index
    fresh_when @day_timeline
  end

  private

    def redirect_to_current_user_when_in_account
      if Current.account.present? && Current.user.present?
        redirect_to user_path(Current.user) and return
      end
    end
end
