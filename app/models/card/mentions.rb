module Card::Mentions
  extend ActiveSupport::Concern

  included do
    include ::Mentions

    def mentionable?
      published?
    end

    def should_check_mentions?
      was_just_published?
    end
  end

  # 支持跨账号提及：对全局活跃用户创建 Mention，便于被提及人通过通知/链接访问卡片
  def mentionable_users
    User.active
  end

  # 同步创建 Mention，确保被 @ 用户点击链接时记录已存在、通知能正确发出；mentioner 为空时用卡片创建者
  def create_mentions_later
    mentioner = Current.user || creator
    return if mentioner.blank?
    Mention::CreateJob.perform_now(self, mentioner: mentioner)
  end
end
