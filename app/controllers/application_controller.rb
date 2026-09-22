class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_current_season
  after_action :discourage_indexing

  helper_method :current_user, :current_season, :admin?, :indexable?

  # Pages with personal details, like player names, club addresses and phone
  # numbers, are kept out of search indexes. Indexing is therefore opt in: an
  # action is only indexed when its controller allows it here.
  def self.allow_indexing(only:)
    before_action(only:) { @indexable = true }
  end

  private
    attr_reader :current_season, :season

    # Public pages skip the authentication callback, so the session is resumed
    # here to be able to show editing links to signed in users.
    def current_user
      Current.user if authenticated?
    end

    # Only admins maintain the competition data, captains are limited to
    # editing matches.
    def admin?
      current_user&.admin? || false
    end

    # Only the pages that were allowed with `allow_indexing` may appear in a
    # search index. The text exports list players, so they are never indexed.
    def indexable?
      @indexable.present? && request.format.html?
    end

    # Responses that may not be indexed say so in a header as well as in the
    # layout, because the text exports have no markup to carry a meta tag.
    def discourage_indexing
      response.headers["X-Robots-Tag"] = "noindex, nofollow" unless indexable?
    end

    # Season pages carry the season slug in their path, e.g.
    # /season/voorjaar-2026/teams. Without a slug the most recent season is shown.
    def set_current_season
      @season = @current_season =
        if params.key?(:season_slug)
          visible_seasons.with_slug.find_by!(slug: params[:season_slug])
        else
          visible_seasons.with_slug.recent.first
        end
    end

    # Seasons that are still a draft are only prepared by admins, so they stay
    # out of sight for everybody else.
    def visible_seasons
      admin? ? Season.all : Season.published
    end

    # Records are addressed without a season in their path, so the season of
    # the record that is shown becomes the season of the page. This keeps the
    # navigation within the season the visitor is looking at.
    def set_current_season_from(record)
      season = record&.season
      return if season.blank?

      raise ActiveRecord::RecordNotFound if season.draft? && !admin?

      @season = @current_season = season
    end

    def require_admin!
      head :unauthorized unless admin?
    end

    # A season that has ended keeps its results, so they can no longer be
    # edited.
    def require_editable_season!
      return if @season.nil? || @season.editable?

      redirect_to(season_url(@season), alert: "Dit seizoen is #{helpers.season_phase_name(@season)}.", status: :see_other)
    end

    # A season is played with the leagues and teams it was prepared with, so
    # they can only be added while the season is still a draft.
    def require_draft_season!
      redirect_to(season_url(@season), alert: "Dit seizoen is al gestart.", status: :see_other) unless @season.nil? || @season.draft?
    end

    # Editing competition data is only possible within a season, which does not
    # exist yet on a freshly deployed application.
    def require_season!
      redirect_to seasons_url, alert: "Maak eerst een seizoen aan." unless @season
    end
end
