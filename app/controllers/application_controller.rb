class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_current_season

  helper_method :current_user, :current_season

  private
    attr_reader :current_season, :season

    # Public pages skip the authentication callback, so the session is resumed
    # here to be able to show editing links to signed in users.
    def current_user
      Current.user if authenticated?
    end

    # Season pages carry the season slug in their path, e.g.
    # /season/voorjaar-2026/teams. Without a slug the most recent season is shown.
    def set_current_season
      @season = @current_season = Season.find_by(slug: params[:season_slug]) || Season.recent.first
    end

    # Records are addressed without a season in their path, so the season of
    # the record that is shown becomes the season of the page. This keeps the
    # navigation within the season the visitor is looking at.
    def set_current_season_from(record)
      @season = @current_season = record.season if record&.season
    end

    def require_admin!
      head :unauthorized unless current_user&.admin?
    end

    # Editing competition data is only possible within a season, which does not
    # exist yet on a freshly deployed application.
    def require_season!
      redirect_to seasons_url, alert: "Maak eerst een seizoen aan." unless @season
    end
end
