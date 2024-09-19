class Accounts::JoinCodesController < ApplicationController
  def show
    respond_to do |format|
      format.svg { render inline: qr_code_svg }
    end
  end

  def update
    Current.account.reset_join_code
    redirect_to account_users_path
  end

  private
    def qr_code_svg
      join_url(Current.account.join_code).then do |url|
        RQRCode::QRCode.new(url).as_svg(viewbox: true, fill: :white, color: :black)
      end
    end
end
