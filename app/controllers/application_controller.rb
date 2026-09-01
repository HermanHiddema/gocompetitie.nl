class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Everything is public, editing requires an account.
  allow_unauthenticated_access only: %i[ index show ]

  before_action :set_current_season

  helper_method :current_user, :current_season

  private
    attr_reader :current_season

    def current_user
      Current.user
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
