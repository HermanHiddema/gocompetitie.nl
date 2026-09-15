class ApplicationMailer < ActionMailer::Base
  default from: (
    if Rails.env.production? && !ENV.key?("SECRET_KEY_BASE_DUMMY")
      ENV.fetch("MAILER_FROM_ADDRESS")
    else
      ENV.fetch("MAILER_FROM_ADDRESS", "from@example.com")
    end
  )
  layout "mailer"
end
