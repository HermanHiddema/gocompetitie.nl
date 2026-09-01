class TeamsController < ApplicationController
  allow_unauthenticated_access only: %i[ index show ]

  BOARDS = 3

  before_action :set_team, only: %i[ show edit update destroy ]

  def index
    @teams = @season.teams.includes(:league, :club, team_members: :participant).ordered
  end

  def show
    @members = @team.team_members.includes(:participant).by_board
    @matches = @team.matches.includes(:venue, :black_team, :white_team, games: %i[ black_player white_player ]).scheduled
  end

  def new
    @team = Team.new(league_id: params[:league_id])
    build_missing_team_members
  end

  def edit
    build_missing_team_members
  end

  def create
    @team = Team.new(team_params)

    if @team.save
      redirect_to @team, notice: "Team is toegevoegd."
    else
      build_missing_team_members
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @team.update(team_params)
      redirect_to @team, notice: "Team is bijgewerkt."
    else
      build_missing_team_members
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @team.destroy!
    redirect_to teams_url, notice: "Team is verwijderd.", status: :see_other
  end

  private
    def set_team
      @team = Team.find(params[:id])
    end

    def build_missing_team_members
      (@team.team_members.size...BOARDS).each do |index|
        @team.team_members.build(board_number: index + 1)
      end
      @members = @team.team_members
    end

    def team_params
      params.expect(team: [ :name, :abbrev, :club_id, :league_id, :captain_id, team_members_attributes: [ [ :id, :board_number, :participant_id, :_destroy ] ] ])
    end
end
