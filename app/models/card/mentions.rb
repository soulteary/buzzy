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

  # 非公开看板中 @ 提及的账号内用户即使不在看板上也需创建 Mention，以便其通过通知/链接打开卡片并参与讨论
  def mentionable_users
    account.users
  end
end
