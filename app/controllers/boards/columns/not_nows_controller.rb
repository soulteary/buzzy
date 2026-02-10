class Boards::Columns::NotNowsController < ApplicationController
  include BoardScoped

  def show
    set_page_and_extract_portion_from board_display_cards.postponed.latest.preloaded
    fresh_when etag: @page.records
  end
end
