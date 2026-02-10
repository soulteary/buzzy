require "test_helper"

class Cards::ImagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "destroy" do
    card = cards(:logo)
    card.image.attach(io: file_fixture("moon.jpg").open, filename: "moon.jpg")

    assert card.image.attached?

    delete user_board_card_image_path(card.board.url_user, card.board, card)

    assert_redirected_to card
    assert_not card.reload.image.attached?
  end

  test "destroy as JSON" do
    card = cards(:logo)
    card.image.attach(io: file_fixture("moon.jpg").open, filename: "moon.jpg")

    assert card.image.attached?

    delete user_board_card_image_path(card.board.url_user, card.board, card), as: :json

    assert_response :no_content
    assert_not card.reload.image.attached?
  end
end
