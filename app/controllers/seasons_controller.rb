class SeasonsController < ApplicationController
  allow_unauthenticated_access only: %i[front index show]

  before_action :set_season, only: %i[show edit update destroy]
  before_action :require_admin!, only: %i[new create edit update destroy]

  # The front page shows the most recent season.
  def front
    redirect_to Season.recent.first || seasons_url
  end

  def index
    @seasons = Season.recent
  end

  def show
    respond_to do |format|
      format.html { @leagues = @season.leagues.ordered.includes(teams: [:club, { team_members: :participant }], matches: :games) }
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

  def destroy
    @season.destroy!
    redirect_to seasons_url, notice: "Seizoen is verwijderd.", status: :see_other
  end

  private
    def set_season
      @season = @current_season = Season.find_by!(slug: params[:slug])
    end

    def season_params
      params.expect(season: [:name, :information])
    end
end
