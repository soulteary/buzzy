class Reaction < ApplicationRecord
  include Notifiable

  belongs_to :account, default: -> { reactable.account }
  belongs_to :reactable, polymorphic: true, touch: true
  belongs_to :reacter, class_name: "User", default: -> { Current.user }

  scope :ordered, -> { order(:created_at) }

  after_create :register_card_activity

  delegate :all_emoji?, to: :content

  # 供 Notification 展示与链接：卡片 reaction 为卡片本身，评论 reaction 为评论所属卡片
  def card
    reactable.respond_to?(:card) ? reactable.card : reactable
  end

  def notifiable_target
    card
  end

  private
    def register_card_activity
      reactable.card.touch_last_active_at
    end
end
