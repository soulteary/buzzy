class Cards::Comments::ReactionsController < ApplicationController
  include CardScoped

  before_action :set_comment
  before_action :set_reaction, only: %i[ destroy ]
  before_action :ensure_permision_to_administer_reaction, only: %i[ destroy ]

  def index
  end

  def new
  end

  def create
    @reaction = @comment.reactions.create!(params.expect(reaction: :content))
  end

  def destroy
    @reaction.destroy
  end

  private
    def set_comment
      @comment = @card.comments.find(params[:comment_id])
    end

    def set_reaction
      @reaction = @comment.reactions.find(params[:id])
    end

    def ensure_permision_to_administer_reaction
      head :forbidden if Current.user != @reaction.reacter
    end
end
