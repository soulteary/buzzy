# frozen_string_literal: true

class AddBodyMarkdownToActionTextRichTexts < ActiveRecord::Migration[8.1]
  def change
    add_column :action_text_rich_texts, :body_markdown, :text
  end
end
