module User::Mentionable
  extend ActiveSupport::Concern

  included do
    has_many :mentions, dependent: :destroy, inverse_of: :mentionee

    # Need to set in the included block so that it overrides Action Text's
    def to_attachable_partial_path
      "users/attachable"
    end
  end

  # sgid 无法解析时（如用户已删除）仍用同一套展示逻辑，由 partial 内做占位
  class_methods do
    def to_missing_attachable_partial_path
      "users/missing_attachable"
    end
  end

  def mentioned_by(mentioner, at:)
    mentions.find_or_create_by! source: at, mentioner: mentioner
  end

  def mentionable_handles
    [ initials, first_name, first_name_with_last_name_initial ].collect(&:downcase)
  end

  def content_type
    "application/vnd.actiontext.mention"
  end

  private
    def first_name_with_last_name_initial
      "#{first_name}#{last_name&.first}"
    end
end
