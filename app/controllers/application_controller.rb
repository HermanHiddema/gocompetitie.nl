class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_current_season

  helper_method :current_user, :current_season

  private
    attr_reader :current_season

    # Public pages skip the authentication callback, so the session is resumed
    # here to be able to show editing links to signed in users.
    def current_user
      Current.user if authenticated?
    end

    # Every season has its own subdomain, e.g. voorjaar-2015.gocompetitie.nl.
    # Without a matching subdomain the most recent season is shown.
    def set_current_season
      @season = Season.find_by(slug: request.subdomains.first) || Season.recent.first
    end

    def require_admin!
      head :unauthorized unless current_user&.admin?
    end
end
