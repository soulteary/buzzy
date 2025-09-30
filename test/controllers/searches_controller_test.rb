require "test_helper"

class SearchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    Card.all.each(&:reindex)
    Comment.all.each(&:reindex)

    sign_in_as :kevin
  end

  test "show" do
    get search_path(q: "broken")

    assert_select "li", text: /Layout is broken/
  end

  test "show with card id" do
    get search_path(q: cards(:logo).id)

    assert_select "form[data-controller='auto-submit']"
  end

  test "show with non-existent card id" do
    get search_path(q: "999999")

    assert_select "form[data-controller='auto-submit']", count: 0
    assert_select ".search__empty", text: "No matches"
  end
end
