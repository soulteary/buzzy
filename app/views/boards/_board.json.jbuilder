json.cache! board do
  json.(board, :id, :name, :all_access)
  json.created_at board.created_at.utc
  json.url user_board_url(board.url_user, board)

  json.creator board.creator, partial: "users/user", as: :user
end
