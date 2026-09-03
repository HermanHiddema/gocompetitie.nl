class TeamsController < ApplicationController
  allow_unauthenticated_access only: %i[index show]

  BOARDS = 3

  before_action :set_team, only: %i[show edit update destroy]

  def index
    @teams = @season ? @season.teams.includes(:league, :club, team_members: :participant).ordered : Team.none
  end

  def show
    @members = @team.team_members.includes(:participant).by_board
    @matches = @team.matches.includes(:venue, :black_team, :white_team, games: %i[black_player white_player]).scheduled
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
      ((1..BOARDS).to_a - @team.team_members.map(&:board_number)).each { |board_number| @team.team_members.build(board_number: board_number) }
      @members = @team.team_members
      @available_participants = available_participants
    end

    # Participants without a team, plus the members of this team, so a player
    # can never be assigned to two teams at once.
    def available_participants
      unassigned = @season.participants.where.missing(:team_member)
      return unassigned.by_rating unless @team.persisted?

      unassigned.or(@season.participants.left_joins(:team_member).where(team_members: { team_id: @team.id })).by_rating
    end

    def team_params
      params.expect(team: [:name, :abbrev, :club_id, :league_id, :captain_id, team_members_attributes: [[:id, :board_number, :participant_id, :_destroy]]])
    end
end
