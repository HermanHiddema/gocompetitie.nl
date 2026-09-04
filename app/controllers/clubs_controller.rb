class ClubsController < ApplicationController
  allow_unauthenticated_access only: %i[index show]

  before_action :set_club, only: %i[show edit update destroy]

  def index
    @clubs = (params[:all] ? Club.all : Club.named).ordered
  end

  def show
    @participants = @club.participants.where(season: @season).by_rating
    @teams = @club.teams.includes(:league, :club).where(league: @season ? @season.leagues : League.none).ordered
    @matches = Match.where(black_team: @teams).or(Match.where(white_team: @teams)).scheduled
  end

  def new
    @club = Club.new
  end

  def edit
  end

  def create
    @club = Club.new(club_params)

    if @club.save
      redirect_to @club, notice: "Club is toegevoegd."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @club.update(club_params)
      redirect_to @club, notice: "Club is bijgewerkt."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @club.destroy
      redirect_to clubs_url, notice: "Club is verwijderd.", status: :see_other
    else
      flash.now[:alert] = @club.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_club
      @club = Club.find(params[:id])
    end

    def club_params
      params.expect(club: [:name, :abbrev, :contact_person_id, :website, :info])
    end
end
