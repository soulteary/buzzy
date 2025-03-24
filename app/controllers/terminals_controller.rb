class TerminalsController < ApplicationController
  def show
    @filter = Current.user.filters.from_params params.permit(*Filter::PERMITTED_PARAMS)
    @events = Event.where(bubble: user_bubbles, creator: Current.user).chronologically.reverse_order.limit(20)
  end

  private
    def user_bubbles
      Current.user.accessible_bubbles
    end
end
