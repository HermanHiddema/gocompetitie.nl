class ParticipantsController < ApplicationController
  allow_unauthenticated_access only: %i[index show]

  before_action :set_participant, only: %i[show edit update destroy]
  before_action :require_season!, only: %i[new create]

  def index
    @participants = @season ? @season.participants.includes(:club, :black_games, :white_games, team_member: :team).by_rating : Participant.none
    @show_club = true
  end

  def show
    @games = @participant.games.includes(:black_player, :white_player, match: %i[black_team white_team])
  end

  def new
    @participant = Participant.new(season: @season)
  end

  def edit
  end

  def create
    @participant = Participant.new(participant_params)
    @participant.season ||= @season

    if @participant.save
      redirect_to @participant, notice: "Deelnemer is toegevoegd."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @participant.update(participant_params)
      redirect_to @participant, notice: "Deelnemer is bijgewerkt."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @participant.destroy!
    redirect_to participants_url, notice: "Deelnemer is verwijderd.", status: :see_other
  end

  private
    def set_participant
      @participant = Participant.find(params[:id])
    end

    def participant_params
      params.expect(participant: [:firstname, :lastname, :rating, :egd_pin, :club_id, :rank])
    end
end
