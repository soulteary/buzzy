class FiltersController < ApplicationController
  before_action :set_filter, :remember_params, only: :destroy

  def create
    @filter = Current.user.filters.persist! filter_params
    redirect_to bubbles_path(@filter.to_params)
  end

  def destroy
    @filter.destroy!
    redirect_after_destroy
  end

  private
    def set_filter
      @filter = Current.user.filters.find params[:id]
    end

    def remember_params
      @filter_params = @filter.to_params
    end

    def filter_params
      params.permit(*Filter::KNOWN_PARAMS).compact_blank
    end

    def redirect_after_destroy
      if request.referer == root_url
        redirect_to root_path
      else
        redirect_to bubbles_path(@filter_params)
      end
    end
end
