class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    mail subject: "Wachtwoord opnieuw instellen", to: user.email_address
  end
end
