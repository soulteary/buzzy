create_tenant "37signals"

david = find_or_create_user "David Heinemeier Hansson", "david@example.com"
jason = find_or_create_user "Jason Fried", "jason@example.com"
jz    = find_or_create_user "Jason Zimdars", "jz@example.com"
kevin = find_or_create_user "Kevin Mcconnell", "kevin@example.com"

login_as david

create_board("Buzzy", access_to: [ jason, jz, kevin ]).tap do |buzzy|
  create_card("Prepare sign-up page", description: "We need to do this before the launch.", board: buzzy)

  create_card("Prepare sign-up page", description: "We need to do this before the launch.", board: buzzy).tap do |card|
    card.toggle_assignment(kevin)
    if column = card.board&.columns&.sample
      card.triage_into(column)
    end
  end

  create_card("Plain text mentions", description: "We'll support plain text mentions first.", board: buzzy).tap do |card|
    card.toggle_assignment(david)
    card.close
  end
end
