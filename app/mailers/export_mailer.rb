class ExportMailer < ApplicationMailer
  def completed(export)
    @export = export
    @user = export.user

    mail to: @user.identity.email_address, subject: "Your Fizzy export is ready"
  end
end
