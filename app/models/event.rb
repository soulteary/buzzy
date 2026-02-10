class Event < ApplicationRecord
  include ERB::Util, Notifiable, Particulars, Promptable

  belongs_to :account, default: -> { board.account }
  belongs_to :board
  belongs_to :creator, class_name: "User"
  belongs_to :eventable, polymorphic: true

  has_many :webhook_deliveries, class_name: "Webhook::Delivery", dependent: :delete_all

  scope :chronologically, -> { order created_at: :asc, id: :desc }
  scope :preloaded, -> {
    includes(:creator, :board, {
      eventable: [
        :goldness, :closure, :image_attachment,
        { rich_text_body: :embeds_attachments },
        { rich_text_description: :embeds_attachments },
        { card: [ :goldness, :closure, :image_attachment ] }
      ]
    })
  }

  after_create -> { eventable.event_was_created(self) }
  after_create_commit :dispatch_webhooks

  delegate :card, to: :eventable

  def action
    super.inquiry
  end

  def notifiable_target
    eventable
  end

  def description_for(user)
    Event::Description.new(self, user)
  end

  # Renders the system comment body in the current locale (for display to the viewer).
  # Used when comment.event_id is set so the viewer sees the message in their language.
  def system_comment_html
    return unless action.in?(
      %w[
        card_assigned card_unassigned card_closed card_reopened card_postponed
        card_auto_postponed card_title_changed card_board_changed card_triaged
        card_sent_back_to_triage
      ]
    )
    creator_name = h(creator.name)
    case action.to_s
    when "card_assigned"
      I18n.t("events.system_comment.card_assigned_html", creator_name: creator_name, assignee_names: h(assignees.pluck(:name).to_sentence)).html_safe
    when "card_unassigned"
      I18n.t("events.system_comment.card_unassigned_html", creator_name: creator_name, assignee_names: h(assignees.pluck(:name).to_sentence)).html_safe
    when "card_closed"
      I18n.t("events.system_comment.card_closed_html", creator_name: creator_name, column: I18n.t("columns.done")).html_safe
    when "card_reopened"
      I18n.t("events.system_comment.card_reopened_html", creator_name: creator_name).html_safe
    when "card_postponed"
      I18n.t("events.system_comment.card_postponed_html", creator_name: creator_name, column: I18n.t("columns.not_now")).html_safe
    when "card_auto_postponed"
      I18n.t("events.system_comment.card_auto_postponed_html", column: I18n.t("columns.not_now")).html_safe
    when "card_title_changed"
      I18n.t("events.system_comment.card_title_changed_html", creator_name: creator_name, old_title: h(particulars.dig("particulars", "old_title")), new_title: h(particulars.dig("particulars", "new_title"))).html_safe
    when "card_board_changed"
      I18n.t("events.system_comment.card_board_changed_html", creator_name: creator_name, old_board: h(particulars.dig("particulars", "old_board")), new_board: h(particulars.dig("particulars", "new_board"))).html_safe
    when "card_triaged"
      I18n.t("events.system_comment.card_triaged_html", creator_name: creator_name, column: h(particulars.dig("particulars", "column"))).html_safe
    when "card_sent_back_to_triage"
      I18n.t("events.system_comment.card_sent_back_to_triage_html", creator_name: creator_name, column: I18n.t("columns.maybe")).html_safe
    end
  end

  private
    def dispatch_webhooks
      Event::WebhookDispatchJob.perform_later(self)
    end
end
