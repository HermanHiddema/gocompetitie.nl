class SeasonsController < ApplicationController
  allow_unauthenticated_access only: %i[front index show]
  allow_indexing only: %i[index show]

  before_action :set_season, only: %i[show edit update destroy start finish]
  before_action :require_admin!, only: %i[new create edit update destroy start finish]
  before_action :require_editable_season!, only: %i[edit update destroy]

  # The front page shows the season that is being played, or the season that
  # was finished most recently.
  def front
    redirect_to Season.current || seasons_url
  end

  def index
    @seasons = visible_seasons.recent
    Season.preload_statistics(@seasons)
  end

  def show
    respond_to do |format|
      format.html { @leagues = @season.leagues.ordered.includes(teams: [:club, { team_members: :participant }], matches: [:games, { league: :season }]) }
      format.text { render plain: @season.results.join("\n") }
    end
  end

  def new
    @season = Season.new
  end

  def edit
  end

  def create
    @season = Season.new(season_params)

    if @season.save
      redirect_to @season, notice: "Seizoen is toegevoegd."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @season.update(season_params)
      redirect_to @season, notice: "Seizoen is bijgewerkt."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def start
    if @season.start!
      redirect_to @season, notice: "Seizoen is gestart."
    end
  rescue ActiveRecord::RecordInvalid
    redirect_to @season, alert: @season.errors.full_messages.to_sentence
  end

  def finish
    @season.finish!
    redirect_to @season, notice: "Seizoen is afgesloten."
  rescue ActiveRecord::RecordInvalid
    redirect_to @season, alert: @season.errors.full_messages.to_sentence
  end

  def destroy
    @season.destroy!
    redirect_to seasons_url, notice: "Seizoen is verwijderd.", status: :see_other
  end

  private
    def set_season
      @season = @current_season = visible_seasons.find_by!(slug: params[:slug])
    end

    def season_params
      params.expect(season: [:name, :information, :handicap_adjustment])
    end
end
