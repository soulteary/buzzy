class Cards::PinsController < ApplicationController
  include CardScoped

  skip_before_action :ensure_board_editable
  skip_before_action :ensure_not_mention_only_access, only: %i[ show create destroy ]

  def show
    fresh_when etag: @card.pin_for(pinning_user_for(@card)) || "none"
  end

  def create
    user = pinning_user_for(@card)
    return head(:forbidden) if user.blank?
    return head(:forbidden) unless card_pinnable_by_current_user?(@card)
    @pin = @card.pin_by user

    broadcast_add_pin_to_tray(user)

    respond_to do |format|
      format.turbo_stream { render_pin_button_replacement }
      format.json { head :no_content }
    end
  end

  def destroy
    user = pinning_user_for(@card)
    return head(:forbidden) if user.blank?
    return head(:forbidden) unless card_pinnable_by_current_user?(@card)
    @pin = @card.unpin_by user

    broadcast_remove_pin_from_tray(user)

    respond_to do |format|
      format.turbo_stream { render_pin_button_replacement }
      format.json { head :no_content }
    end
  end

  private
    def broadcast_add_pin_to_tray(user)
      @pin.broadcast_prepend_to [ user, :pins_tray ], target: "pins", partial: "my/pins/pin"
    end

    def broadcast_remove_pin_from_tray(user)
      @pin.broadcast_remove_to [ user, :pins_tray ]
    end

    def render_pin_button_replacement
      render turbo_stream: turbo_stream.replace([ @card, :pin_button ], partial: "cards/pins/pin_button", locals: { card: @card })
    end
end
