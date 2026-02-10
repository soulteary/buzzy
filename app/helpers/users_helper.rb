module UsersHelper
  def role_display_name(user)
    I18n.t("users.roles.#{user.role}")
  end
end
