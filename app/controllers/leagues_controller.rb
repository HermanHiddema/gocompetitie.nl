class LeaguesController < ApplicationController
  allow_unauthenticated_access only: %i[ index show ]

  before_action :set_league, only: %i[ show edit update destroy ]

  def index
    @leagues = @season.leagues.ordered.includes(teams: [ :club, { team_members: :participant } ], matches: :games)
  end

  def show
    @teams = @league.ranked_teams
    @matches = @league.matches.includes(:venue, :black_team, :white_team, :games).scheduled
    @participants = @league.participants.includes(:club, team_member: :team).to_a.sort_by(&:rating_change).reverse

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
    @league = League.new(league_params)
    @league.season ||= @season

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
    redirect_to leagues_url, notice: "Poule is verwijderd.", status: :see_other
  end

  private
    def set_league
      @league = League.find(params[:id])
    end

    def league_params
      params.expect(league: [ :name, :position, :season_id ])
    end
end
