class ConversationsController < ApplicationController
  def show
    @conversation = Current.user.conversation
  end
end
