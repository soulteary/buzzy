class TagsController < ApplicationController
  def index
    set_page_and_extract_portion_from Current.account.tags.alphabetically.includes(:cards)
  end
end
