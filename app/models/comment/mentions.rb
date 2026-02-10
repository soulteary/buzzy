module Comment::Mentions
  extend ActiveSupport::Concern

  included do
    include ::Mentions

    def mentionable?
      card.published?
    end
  end

  # 与 Card::Mentions 一致：被 @ 的账号内用户即使不在看板上也创建 Mention，以便其可打开卡片并参与讨论
  def mentionable_users
    card.account.users
  end
end
