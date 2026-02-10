class Cards::ColumnsController < ApplicationController
  include CardScoped

  def edit
    @columns = @board.columns.sorted

    fresh_when etag: [ @card, @columns ]
  end
end
