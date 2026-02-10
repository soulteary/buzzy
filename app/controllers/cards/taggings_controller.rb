class Cards::TaggingsController < ApplicationController
  include CardScoped

  before_action :forbid_new_tagging_unless_editable, only: :new

  def new
    @tagged_with = @card.tags.alphabetically
    @tags = Current.account.tags.all.alphabetically.where.not(id: @tagged_with)
    fresh_when etag: [ @tags, @card.tags ]
  end

  def create
    @card.toggle_tag_with sanitized_tag_title_param

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  private
    def forbid_new_tagging_unless_editable
      head :forbidden unless card_editable_by_current_user?(@card)
    end

    def sanitized_tag_title_param
      params.required(:tag_title).strip.gsub(/\A#/, "")
    end
end
