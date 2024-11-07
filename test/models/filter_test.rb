require "test_helper"

class FilterTest < ActiveSupport::TestCase
  test "persistence" do
    assert_difference "Filter.count", +1 do
      filter = users(:david).filters.persist!(indexed_by: "most_boosted")

      assert_changes "filter.reload.updated_at" do
        assert_equal filter, users(:david).filters.persist!(indexed_by: "most_boosted")
      end
    end
  end

  test "bubbles" do
    Current.set session: sessions(:david) do
      @inaccessible_bucket = accounts("37s").buckets.create! name: "Inaccessible Bucket"
      @inaccessible_bubble = @inaccessible_bucket.bubbles.create!
    end

    assert_not_includes users(:kevin).filters.new.bubbles, @inaccessible_bubble
  end

  test "turning into params" do
    expected = { indexed_by: "most_discussed", tag_ids: [ tags(:mobile).id ], assignee_ids: [ users(:jz).id ], filter_id: filters(:jz_assignments).id }
    assert_equal expected.stringify_keys, filters(:jz_assignments).to_params.to_h
  end

  test "cacheable" do
    assert_not filters(:jz_assignments).cacheable?
    assert users(:david).filters.create!(bucket_ids: [ buckets(:writebook).id ]).cacheable?
  end

  test "resource removal" do
    filter = users(:david).filters.create! tag_ids: [ tags(:mobile).id ], bucket_ids: [ buckets(:writebook).id ]
    assert_includes filter.tags, tags(:mobile)
    assert_includes filter.buckets, buckets(:writebook)

    assert_changes "filter.reload.updated_at" do
      tags(:mobile).destroy!
    end

    assert_changes "Filter.exists?(filter.id)" do
      buckets(:writebook).destroy!
    end
  end

  test "summary" do
    assert_equal "<mark>Most discussed</mark>, tagged <mark>#Mobile</mark>, and assigned to <mark>JZ</mark> in <mark>all projects</mark>", filters(:jz_assignments).summary
  end

  test "plain summary" do
    assert_equal "Most discussed, tagged #Mobile, and assigned to JZ in all projects", filters(:jz_assignments).plain_summary
  end
end
