require "application_system_test_case"

class SmokeTest < ApplicationSystemTestCase
  # Join-by-code flow removed for single-user-per-account architecture
  test "joining an account", skip: "Join-by-code entry has been removed (single-user-per-account)" do
    account = accounts("37s")
    visit join_url(code: account.join_code.code, script_name: account.slug)
    fill_in "Email address", with: "newbie@example.com"
    click_on "Continue"
    assert_selector "h1", text: "Check your email"
  end

  test "create a card" do
    sign_in_as(users(:david))

    visit user_board_url(boards(:writebook).url_user, boards(:writebook))
    click_on "Add a card"
    fill_in "card_title", with: "Hello, world!"
    fill_in_markdown_editor with: "I am editing this thing"
    click_on "Create card"

    assert_selector "h3", text: "Hello, world!"
  end

  test "active storage attachments" do
    sign_in_as(users(:david))
    card = cards(:layout)

    visit user_board_card_url(card.board.url_user, card.board, card)
    within("##{dom_id(card, :new_comment)}") do
      fill_in_markdown_editor with: "Here is a comment"
      attach_file file_fixture("moon.jpg") do
        click_on "Upload file"
      end
    end

    # Wait for DirectUpload to finish and token to be inserted (chip or blob-sgid in content)
    within("##{dom_id(card, :new_comment)}") do
      assert_selector ".markdown-editor__attachment-chip", wait: 10
      click_on "Post"
    end

    # Rendered comment body: find the comment we just posted (contains our text) then its attachment
    comment_body = find(".comment .rich-text-content", text: "Here is a comment")
    within(comment_body.find(:xpath, "./ancestor::*[contains(concat(' ', normalize-space(@class), ' '), ' comment ')][1]")) do
      assert_selector "figure.attachment[data-content-type='image/jpeg']"
      assert_selector "figure.attachment img[src*='/rails/active_storage']"
      assert_selector "figcaption span.attachment__name", text: "moon.jpg"
    end

    # Click the image to open the lightbox
    comment_body.find("figure.attachment a").click

    assert_selector "dialog.lightbox[open]"
    within("dialog.lightbox") do
      assert_selector "img.lightbox__image[src*='/rails/active_storage']"
    end
  end

  test "dismissing notifications" do
    sign_in_as(users(:david))

    notif = notifications(:logo_card_david_mention_by_jz)

    assert_selector "div##{dom_id(notif)}"

    within_window(open_new_window) { visit user_board_card_url(notif.card.board.url_user, notif.card.board, notif.card) }

    assert_no_selector "div##{dom_id(notif)}"
  end

  test "dragging card to a new column" do
    sign_in_as(users(:david))

    card = Card.find("03axhd1h3qgnsffqplkyf28fv")
    assert_nil(card.column)

    visit user_board_url(boards(:writebook).url_user, boards(:writebook))

    card_el = page.find("#article_card_03axhd1h3qgnsffqplkyf28fv")
    column_el = page.find("#column_03axmcferfmbnv4qg816nw6bg")
    cards_count = column_el.find(".cards__expander-count").text.to_i

    card_el.drag_to(column_el)

    column_el.find(".cards__expander-count", text: cards_count + 1)
    assert_equal("Triage", card.reload.column.name)
  end

  test "post a comment with markdown editor content" do
    sign_in_as(users(:david))
    card = cards(:layout)
    content = "Comment body from markdown editor"

    visit user_board_card_url(card.board.url_user, card.board, card)

    within("##{dom_id(card, :new_comment)}") do
      fill_in_markdown_editor with: content
      click_on "Post"
    end

    assert_selector ".comment .action-text-content", text: content
    assert_equal content, card.reload.comments.order(created_at: :desc).first.body.to_plain_text
  end

  test "shows mention autocomplete when typing at in markdown editor" do
    sign_in_as(users(:david))
    card = cards(:layout)

    visit user_board_card_url(card.board.url_user, card.board, card)

    within("##{dom_id(card, :new_comment)}") do
      type_in_markdown_editor("@")
      assert_selector ".markdown-prompt__menu.is-open .markdown-prompt__item", wait: 10
    end
  end

  test "mention autocomplete inserts token when selecting user with Enter" do
    sign_in_as(users(:david))
    card = cards(:layout)
    mentionee = users(:kevin)

    visit user_board_card_url(card.board.url_user, card.board, card)

    within("##{dom_id(card, :new_comment)}") do
      type_in_markdown_editor("@Kev")
      assert_selector ".markdown-prompt__menu.is-open .markdown-prompt__item", wait: 10
      send_keys(:enter)
    end

    value = get_markdown_editor_value
    assert_match %r{\[@#{Regexp.escape(mentionee.name)}\]\(#{Regexp.escape(mentionee.mention_handle)}\)}, value,
      "Editor should contain mention token [@name](mention_handle) after selecting user"
  end

  test "mention autocomplete stays open and filters when typing partial name" do
    sign_in_as(users(:david))
    card = cards(:layout)

    visit user_board_card_url(card.board.url_user, card.board, card)

    within("##{dom_id(card, :new_comment)}") do
      type_in_markdown_editor("@")
      assert_selector ".markdown-prompt__menu.is-open .markdown-prompt__item", wait: 10
      type_in_markdown_editor("Kev")
      assert_selector ".markdown-prompt__menu.is-open .markdown-prompt__item", wait: 5
      # Menu should show Kevin when filtering by "Kev"
      assert_selector ".markdown-prompt__menu.is-open .markdown-prompt__item", text: "Kevin"
    end
  end

  test "mention autocomplete supports consecutive mentions across accounts" do
    sign_in_as(users(:david))
    card = cards(:layout)

    visit user_board_card_url(card.board.url_user, card.board, card)

    within("##{dom_id(card, :new_comment)}") do
      type_in_markdown_editor("@Mike")
      assert_selector ".markdown-prompt__menu.is-open .markdown-prompt__item", text: "Initech LLC", wait: 10
      send_keys(:enter)

      type_in_markdown_editor("@Kev")
      assert_selector ".markdown-prompt__menu.is-open .markdown-prompt__item", text: "37signals", wait: 10
      send_keys(:enter)
    end

    value = get_markdown_editor_value
    assert_equal 2, value.scan(/\[@[^\]]+\]\([^)]+\)/).size
  end

  private
    def sign_in_as(user)
      unless Buzzy.session_transfer_enabled?
        skip "Session transfer is disabled (DISABLE_SESSION_TRANSFER or Forward Auth); sign-in via transfer not available"
      end
      if forward_auth_enabled?
        skip "Forward Auth is enabled; system test sign-in via session transfer is not available"
      end
      transfer_id = user.identity.transfer_id
      skip "Identity has session transfer disabled" if transfer_id.blank?
      visit session_transfer_url(transfer_id, script_name: nil)
      assert_selector "h1", text: "Latest Activity"
    end

    def forward_auth_enabled?
      cfg = Rails.application.config.forward_auth
      cfg.is_a?(ForwardAuth::Config) && cfg.enabled?
    end

    def fill_in_markdown_editor(selector = nil, with:)
      wrapper = if selector
        el = find(selector)
        el[:class]&.include?("markdown-editor") ? el : el.find(".markdown-editor")
      else
        find(".markdown-editor")
      end
      page.execute_script(<<~JS, wrapper.native, with)
        (function(wrap, value) {
          if (wrap.easymde) {
            wrap.easymde.value(value);
            wrap.easymde.codemirror.refresh();
          } else {
            var ta = wrap.querySelector('.markdown-editor__textarea');
            if (ta) { ta.value = value; ta.dispatchEvent(new Event('input', { bubbles: true })); }
          }
          var hidden = wrap.querySelector('input[type="hidden"]');
          if (hidden) hidden.value = value;
        })(arguments[0], arguments[1])
      JS
    end

    def type_in_markdown_editor(text, selector = nil)
      wrapper = if selector
        el = find(selector)
        el[:class]&.include?("markdown-editor") ? el : el.find(".markdown-editor")
      else
        find(".markdown-editor")
      end
      page.execute_script(<<~JS, wrapper.native, text)
        (function(wrap, text) {
          if (wrap.easymde) {
            var cm = wrap.easymde.codemirror;
            cm.focus();
            cm.replaceSelection(text);
          } else {
            var ta = wrap.querySelector('.markdown-editor__textarea');
            if (!ta) return;
            ta.focus();
            var start = ta.selectionStart || 0;
            var end = ta.selectionEnd || 0;
            var before = ta.value.slice(0, start);
            var after = ta.value.slice(end);
            ta.value = before + text + after;
            ta.selectionStart = ta.selectionEnd = before.length + text.length;
            ta.dispatchEvent(new Event('input', { bubbles: true }));
          }
        })(arguments[0], arguments[1])
      JS
    end

    def get_markdown_editor_value(selector = nil)
      wrapper = if selector
        el = find(selector)
        el[:class]&.include?("markdown-editor") ? el : el.find(".markdown-editor")
      else
        find(".markdown-editor")
      end
      page.evaluate_script(<<~JS, wrapper.native)
        (function() {
          var wrap = arguments[0];
          if (wrap.easymde) return wrap.easymde.value();
          var ta = wrap.querySelector('.markdown-editor__textarea');
          return ta ? ta.value : '';
        })()
      JS
    end
end
