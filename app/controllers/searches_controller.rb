require "ostruct"

class SearchesController < ApplicationController
  include Turbo::DriveHelper

  SEARCH_PAGE_SIZE = 25

  def show
    if card = Current.user.accessible_cards.find_by_id(params[:q])
      @card = card
    else
      result = Current.user.search(params[:q])
      if result.is_a?(Array)
        set_page_from_search_array(result)
      else
        set_page_and_extract_portion_from result
      end
      @recent_search_queries = Current.user.search_queries.order(updated_at: :desc).limit(10)
    end
  end

  private
    def set_page_from_search_array(combined)
      page_num = [ 1, params[:page].to_i ].max
      offset = (page_num - 1) * SEARCH_PAGE_SIZE
      records = combined.slice(offset, SEARCH_PAGE_SIZE) || []
      total_pages = combined.empty? ? 1 : [ 1, (combined.size.to_f / SEARCH_PAGE_SIZE).ceil ].max
      @page = OpenStruct.new(
        records: records,
        number: page_num,
        before_last?: page_num < total_pages,
        last?: page_num >= total_pages,
        used?: combined.any?,
        next_param: page_num + 1
      )
    end
end
