class Cards::CommentsController < ApplicationController
  include CardScoped

  # 跨账号评论：当前身份在看板所属账号下可能无 User，set_board 回退会先找到看板，再在此补全 Current.user，
  # 避免 require_user_in_account / ensure_can_access_account 在 show/edit/update/destroy/create 上直接返回空 frame。
  allow_unauthorized_access only: %i[ show edit update destroy create ]
  skip_before_action :require_user_in_account, only: %i[ show edit update destroy create ]
  before_action :set_user_for_cross_account_comment, only: %i[ show edit update destroy create ]

  before_action :set_comment, only: %i[ show edit update destroy ]
  before_action :ensure_creatorship, only: %i[ edit update destroy ]
  before_action :ensure_card_is_commentable, only: :create
  skip_before_action :ensure_not_mention_only_access
  # 评论区互动不要求看板可编辑：能查看卡片即可评论（管理员查看他人卡片、被 @ 提及用户参与讨论等）
  skip_before_action :ensure_board_editable

  def index
    set_page_and_extract_portion_from @card.comments.chronologically.preloaded
  end

  def create
    @comment = @card.comments.create!(comment_params)

    respond_to do |format|
      format.turbo_stream
      format.json { head :created, location: user_board_card_comment_path(@card.board.url_user, @card.board, @card, @comment, format: :json) }
    end
  end

  def show
  end

  def edit
  end

  def update
    @comment.update! comment_params

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  def destroy
    @comment.destroy

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  private
    def set_comment
      @comment = @card.comments.find(params[:id])
    end

    def ensure_creatorship
      head :forbidden if Current.user.blank?
      head :forbidden if Current.user != @comment.creator
    end

    def ensure_card_is_commentable
      head :forbidden unless @card.commentable?
    end

    def comment_params
      params.expect(comment: [ :body, :created_at ])
    end
end
