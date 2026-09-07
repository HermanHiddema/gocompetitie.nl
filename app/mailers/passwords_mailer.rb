class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    mail from: "no-reply@gocompetitie.nl", subject: "Wachtwoord opnieuw instellen", to: user.email_address
  end
end
