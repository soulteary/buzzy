class Command::Search < Command
  store_accessor :data, :query, :params

  def title
    "Search '#{query}'"
  end

  def execute
    redirect_to cards_path(**params.merge("terms[]": query.presence))
  end
end
