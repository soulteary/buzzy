class Command::Parser::Context
  attr_reader :user

  def initialize(user, url:)
    @user = user
    extract_url_components(url)
  end

  def cards
    if controller == "cards" && action == "show"
      user.accessible_cards.where id: params[:id]
    elsif controller == "cards" && action == "index"
      filter.cards
    end
  end

  def filter
    user.filters.from_params params.reverse_merge(**FilterScoped::DEFAULT_PARAMS)
  end

  private
    def extract_url_components(url)
      uri = URI.parse(url)
      route = Rails.application.routes.recognize_path(uri.path)
      @controller = route[:controller]
      @action = route[:action]
      @params = Rack::Utils.parse_nested_query(uri.query)
    end

    attr_reader :controller, :action, :params
end
