require "test_helper"

class Card::ExportableTest < ActiveSupport::TestCase
  test "export_json returns card data as JSON" do
    card = cards(:logo)

    json = JSON.parse(card.export_json)

    assert_equal 1, json["number"]
    assert_equal "The logo isn't big enough", json["title"]
    assert_equal "Writebook", json["board"]
    assert_equal "Triage", json["status"]
    assert_equal users(:david).id, json["creator"]["id"]
    assert_equal "David", json["creator"]["name"]
    assert_equal "david@37signals.com", json["creator"]["email"]
    assert_equal "", json["description"]
    assert_equal 5, json["comments"].count
    assert_equal card.created_at.iso8601, json["created_at"]
    assert_equal card.updated_at.iso8601, json["updated_at"]
  end

  test "export_attachments returns attachment paths and blobs" do
    card = cards(:logo)

    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("moon.jpg").open,
      filename: "moon.jpg",
      content_type: "image/jpeg"
    )
    attachment_html = ActionText::Attachment.from_attachable(blob).to_html
    card.update!(description: "<p>Here is an image:</p>#{attachment_html}")

    attachments = card.export_attachments

    assert_equal 1, attachments.count
    assert_equal file_fixture("moon.jpg").binread, attachments.first[:blob].download
    assert attachments.first[:path].start_with?("#{card.number}/")
  end

  test "export_json renders mention as @first_name" do
    card = cards(:logo)
    mention_html = ActionText::Attachment.from_attachable(users(:kevin)).to_html
    card.update!(description: "<p>Hello #{mention_html}</p>")

    json = JSON.parse(card.export_json)

    assert_includes json["description"], "@kevin"
    assert_includes json["description"], "mention"
  end

  test "export_json renders missing mention label when user cannot be resolved" do
    card = cards(:logo)
    card.update!(
      description: <<~HTML.squish
        <p>
          Hello
          <action-text-attachment content-type="application/vnd.actiontext.mention" sgid="invalid-sgid" gid="gid://buzzy/User/non-existent">x</action-text-attachment>
        </p>
      HTML
    )

    json = JSON.parse(card.export_json)

    assert_includes json["description"], I18n.t("users.missing_attachable_label")
    assert_includes json["description"], "mention--missing"
  end

  test "export_json resolves mention via gid when sgid is invalid" do
    user = users(:kevin)
    card = cards(:logo)
    card.update!(
      description: "<p>Hey <action-text-attachment content-type=\"application/vnd.actiontext.mention\" sgid=\"invalid\" gid=\"#{user.to_global_id}\">@kevin</action-text-attachment></p>"
    )

    json = JSON.parse(card.export_json)

    assert_includes json["description"], "@kevin"
    assert_includes json["description"], "mention"
  end
end
