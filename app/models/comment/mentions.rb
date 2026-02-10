module Comment::Mentions
  extend ActiveSupport::Concern

  included do
    include ::Mentions

    def mentionable?
      card.published?
    end
  end

  # 与 Card::Mentions 一致：支持跨账号提及，对全局活跃用户创建 Mention
  def mentionable_users
    User.active
  end

  # 同步创建 Mention，确保被 @ 用户能通过链接访问卡片并收到通知；mentioner 为空时用评论创建者
  def create_mentions_later
    mentioner = Current.user || creator
    return if mentioner.blank?
    Mention::CreateJob.perform_now(self, mentioner: mentioner)
  end
end
