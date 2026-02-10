require "test_helper"

class Search::StemmerTest < ActiveSupport::TestCase
  test "stem single word" do
    result = Search::Stemmer.stem("running")

    assert_equal "run", result
  end

  test "stem multiple words" do
    result = Search::Stemmer.stem("test, running      JUMPING & walking")

    assert_equal "test run jump walk", result
  end

  test "stem CJK character-level tokenization" do
    result = Search::Stemmer.stem("日本語")

    assert_equal "日 本 語", result
  end

  test "stem mixed CJK and English" do
    result = Search::Stemmer.stem("标题 title 中文")

    assert_equal "标 题 title 中 文", result
  end
end
