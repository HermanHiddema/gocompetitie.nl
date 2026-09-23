class ParticipantsController < ApplicationController
  allow_unauthenticated_access only: %i[index show]

  before_action :set_participant, only: %i[show edit update destroy]
  before_action :require_admin!, only: %i[new create edit update destroy import_egd]
  before_action :require_season!, only: %i[new create import_egd]
  before_action :require_editable_season!, only: %i[new create edit update destroy import_egd]

  def index
    @participants = @season ? @season.participants.includes(:club, :home_games, :away_games, team_member: :team).by_rating : Participant.none
    @show_club = true
  end

  def show
    @games = @participant.games.includes(:home_player, :away_player, match: [{ league: :season }, :home_team, :away_team])
  end

  def new
    @participant = Participant.new(season: @season)
    @egd_search = params[:egd_search].to_s.strip
    @egd_players = search_egd_players
  end

  def edit
  end

  def create
    @participant = Participant.new(participant_params)
    @participant.season ||= @season

    if @participant.save
      redirect_to @participant, notice: "Speler is toegevoegd."
    else
      render :new, status: :unprocessable_content
    end
  end

  def import_egd
    participant = @season.upsert_egd_player(egd_player_params)
    redirect_to participant, notice: "Speler is uit de EGD overgenomen."
  end

  def update
    if @participant.update(participant_params)
      redirect_to @participant, notice: "Speler is bijgewerkt."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @participant.destroy!
    redirect_to participants_url(season_slug: @participant.season.slug), notice: "Speler is verwijderd.", status: :see_other
  end

  private
    def set_participant
      @participant = Participant.find(params[:id])
      set_current_season_from(@participant)
    end

    def participant_params
      params.expect(participant: [:firstname, :lastname, :rating, :egd_pin, :club_id, :rank])
    end

    def egd_player_params
      params.expect(egd_player: %i[pin firstName lastName club grade rating]).to_h.stringify_keys
    end

    def search_egd_players
      return [] if @egd_search.blank?

      egd_client.search_players(@egd_search, limit: 20).first(20)
    rescue Egd::Error => error
      @egd_search_error = error.message
      []
    end

    def egd_client
      Egd::Client.new
    end
end
