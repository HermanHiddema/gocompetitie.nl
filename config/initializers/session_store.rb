# Share the session cookie with subdomains, so that it is valid both on the
# apex domain and on www.
Rails.application.config.session_store :cookie_store,
  key: "_go_competitie_session",
  domain: Rails.application.config.x.cookie_domain
