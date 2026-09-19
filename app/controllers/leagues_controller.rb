class LeaguesController < ApplicationController
  allow_unauthenticated_access only: :show
  allow_indexing only: :show

  before_action :set_league, only: %i[show edit update destroy]
  before_action :require_admin!, only: %i[new create edit update destroy]
  before_action :set_selected_season, only: %i[new create]
  before_action :require_season!, only: %i[new create]
  before_action :require_editable_season!, only: %i[new create edit update destroy]
  before_action :require_draft_season!, only: %i[new create]

  def show
    @teams = @league.teams.includes(:league, :club, team_members: :participant).ordered
    @matches = @league.matches.includes(:venue, :home_team, :away_team, :games, league: :season).scheduled
    @participants = @league.participants.includes(:club, :home_games, :away_games, team_member: :team).to_a.sort_by(&:rating_change).reverse

    respond_to do |format|
      format.html
      format.text { render plain: @league.results.join("\n") }
    end
  end

  def new
    @league = @season.leagues.build
  end

  def edit
  end

  def create
    @league = @season.leagues.build(league_params)

    if @league.save
      redirect_to @league, notice: "Poule is toegevoegd."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @league.update(league_params)
      redirect_to @league, notice: "Poule is bijgewerkt."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @league.destroy!
    redirect_to @league.season, notice: "Poule is verwijderd.", status: :see_other
  end

  private
    def set_selected_season
      season_id = params[:season_id] || params.dig(:league, :season_id)
      @season = @current_season = visible_seasons.find(season_id) if season_id.present?
    end

    def set_league
      @league = League.find(params[:id])
      set_current_season_from(@league)
    end

    def league_params
      params.expect(league: [:name, :position])
    end
end
