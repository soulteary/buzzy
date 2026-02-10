class Cards::ReactionsController < ApplicationController
  include CardScoped

  # 跨账号/仅公开可访问时与评论一致：先通过 set_board 回退找到看板并补全 Current.user，再渲染 new/create
  allow_unauthorized_access only: %i[ new create ]
  skip_before_action :require_user_in_account, only: %i[ new create ]
  before_action :set_user_for_cross_account_comment, only: %i[ new create ]

  skip_before_action :ensure_board_editable
  skip_before_action :ensure_not_mention_only_access

  before_action :set_reactable

  with_options only: :destroy do
    before_action :set_reaction
    before_action :ensure_permission_to_administer_reaction
  end

  def index
    render "reactions/index"
  end

  def new
    render "reactions/new"
  end

  def create
    @reaction = @reactable.reactions.create!(params.expect(reaction: :content))

    respond_to do |format|
      format.turbo_stream { render "reactions/create" }
      format.json { head :created }
    end
  end

  def destroy
    @reaction.destroy

    respond_to do |format|
      format.turbo_stream { render "reactions/destroy" }
      format.json { head :no_content }
    end
  end

  private
    def set_reactable
      @reactable = @card
    end

    def set_reaction
      @reaction = @reactable.reactions.find(params[:id])
    end

    def ensure_permission_to_administer_reaction
      head :forbidden if Current.user.blank?
      head :forbidden if Current.user != @reaction.reacter
    end
end
