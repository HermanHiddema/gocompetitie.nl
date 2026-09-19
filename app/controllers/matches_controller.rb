class MatchesController < ApplicationController
  allow_unauthenticated_access only: %i[index show]
  allow_indexing only: :index

  BOARDS = 3

  before_action :set_match, only: %i[show edit update destroy]
  before_action :require_admin!, only: %i[new create destroy]
  before_action :require_season!, only: %i[new create]
  before_action :require_editable_season!, only: %i[new create edit update destroy]

  def index
    @matches = @season ? @season.matches.includes(:venue, :home_team, :away_team, :games, league: :season).scheduled : Match.none
  end

  def show
    @games = @match.games.includes(:home_player, :away_player).by_board
  end

  def new
    @league = @season.leagues.find_by(id: params[:league_id])
    @league ||= @season.leagues.joins(:teams).find_by(teams: { id: params[:home_team_id] })
    @league ||= @season.leagues.ordered.first
    @match = @league ? @league.matches.build : Match.new
    @match.home_team_id = params[:home_team_id]
    @match.away_team_id = params[:away_team_id]
    @leagues = @season.leagues.ordered
    @teams = @league ? @league.teams.ordered : @season.teams.ordered
  end

  def edit
    @games = @match.games.includes(:home_player, :away_player).by_board
    @home_players = selectable_players(@match.home_team)
    @away_players = selectable_players(@match.away_team)
  end

  def create
    @league = @season.leagues.find_by(id: match_create_params[:league_id])
    @match = Match.new(match_create_params.except(:league_id))
    @match.league = @league

    if @match.errors.empty? && @match.save
      redirect_to edit_match_url(@match), notice: "Wedstrijd is toegevoegd."
    else
      @match.errors.add(:league, :blank) unless @league
      @leagues = @season.leagues.ordered
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
    redirect_to matches_url(season_slug: @match.season.slug), notice: "Wedstrijd is verwijderd.", status: :see_other
  end

  private
    def set_match
      @match = Match.find(params[:id])
      set_current_season_from(@match)
    end

    # Players of the clubs that make up the team, so guest players from a
    # partner club can be selected as well. Pass ?all=1 to select any player.
    def selectable_players(team)
      participants = @match.season.participants
      participants = participants.where(club_id: related_club_ids(team)) unless params[:all]
      participants.includes(:club).by_rating
    end

    def related_club_ids(team)
      Participant.joins(:team_member)
        .where(team_members: { team_id: team.club.teams.select(:id) })
        .distinct.pluck(:club_id).compact.presence || [team.club_id]
    end

    def match_create_params
      params.expect(match: [:league_id, :venue_id, :playing_date, :playing_time, :home_team_id, :away_team_id])
    end

    def match_update_params
      params.expect(match: [:venue_id, :playing_date, :playing_time, games_attributes: [[:id, :home_id, :away_id, :result, :handicap]]])
    end
end
