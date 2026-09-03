class MatchesController < ApplicationController
  allow_unauthenticated_access only: %i[index show]

  BOARDS = 3

  before_action :set_match, only: %i[show edit update destroy]

  def index
    @matches = @season ? @season.matches.includes(:venue, :black_team, :white_team, :games).scheduled : Match.none
  end

  def show
    @games = @match.games.includes(:black_player, :white_player).by_board
  end

  def new
    @league = @season.leagues.find_by(id: params[:league_id])
    @league ||= @season.leagues.joins(:teams).find_by(teams: { id: params[:black_team_id] })
    @league ||= @season.leagues.ordered.first
    @match = @league ? @league.matches.build : Match.new
    @match.black_team_id = params[:black_team_id]
    @match.white_team_id = params[:white_team_id]
    @leagues = @season.leagues.ordered
    @teams = @league ? @league.teams.ordered : @season.teams.ordered
  end

  def edit
    @games = @match.games.includes(:black_player, :white_player).by_board
    @black_players = selectable_players(@match.black_team)
    @white_players = selectable_players(@match.white_team)
  end

  def create
    @match = Match.new(match_create_params)

    if @match.save
      redirect_to edit_match_url(@match), notice: "Wedstrijd is toegevoegd."
    else
      @leagues = @season.leagues.ordered
      @league = @season.leagues.find_by(id: @match.league_id)
      @teams = @league ? @league.teams.ordered : @season.teams.ordered
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @match.update(match_update_params)
      redirect_to @match, notice: "Wedstrijd is bijgewerkt."
    else
      edit
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @match.destroy!
    redirect_to matches_url, notice: "Wedstrijd is verwijderd.", status: :see_other
  end

  private
    def set_match
      @match = Match.find(params[:id])
    end

    # Players of the clubs that make up the team, so guest players from a
    # partner club can be selected as well. Pass ?all=1 to select any player.
    def selectable_players(team)
      participants = @season.participants
      participants = participants.where(club_id: related_club_ids(team)) unless params[:all]
      participants.includes(:club).by_rating
    end

    def related_club_ids(team)
      Participant.joins(:team_member)
        .where(team_members: { team_id: team.club.teams.select(:id) })
        .distinct.pluck(:club_id).compact.presence || [team.club_id]
    end

    def match_create_params
      params.expect(match: [:league_id, :venue_id, :playing_date, :playing_time, :black_team_id, :white_team_id])
    end

    def match_update_params
      params.expect(match: [:venue_id, :playing_date, :playing_time, games_attributes: [[:id, :black_id, :white_id, :result]]])
    end
end
