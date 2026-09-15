require "active_support/core_ext/integer/time"

Rails.application.configure do
  production_build = ENV.key?("SECRET_KEY_BASE_DUMMY")
  fetch_production_env = lambda do |name, build_default = nil|
    if ENV.key?(name)
      ENV.fetch(name)
    elsif production_build && !build_default.nil?
      build_default
    else
      ENV.fetch(name)
    end
  end

  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [:request_id]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = {
    host: fetch_production_env.call("APP_HOST", "example.com"),
    protocol: fetch_production_env.call("APP_PROTOCOL", "https")
  }

  # Specify outgoing SMTP server via environment variables.
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: fetch_production_env.call("SMTP_ADDRESS", "smtp.example.com"),
    port: fetch_production_env.call("SMTP_PORT", "587"),
    domain: fetch_production_env.call("SMTP_DOMAIN", "example.com"),
    user_name: fetch_production_env.call("SMTP_USERNAME", "user"),
    password: fetch_production_env.call("SMTP_PASSWORD", "password"),
    authentication: fetch_production_env.call("SMTP_AUTHENTICATION", "plain").to_sym,
    enable_starttls_auto: fetch_production_env.call("SMTP_ENABLE_STARTTLS_AUTO", "true") == "true"
  }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [:id]

  # Enable DNS rebinding protection and other `Host` header attacks by listing
  # allowed hosts via a comma-separated RAILS_ALLOWED_HOSTS environment variable.
  config.hosts.concat(
    fetch_production_env.call("RAILS_ALLOWED_HOSTS", "example.com").split(",").map(&:strip).reject(&:empty?)
  )

  # Skip DNS rebinding protection for the default health check endpoint.
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
