class VenuesController < ApplicationController
  allow_unauthenticated_access only: %i[index show]

  before_action :set_venue, only: %i[show edit update destroy]

  def index
    @venues = Venue.includes(:club).ordered
  end

  def show
    @matches = @season ? @venue.matches.where(league: @season.leagues).includes(:black_team, :white_team, :games).scheduled : Match.none
  end

  def new
    @venue = Venue.new
  end

  def edit
  end

  def create
    @venue = Venue.new(venue_params)

    if @venue.save
      redirect_to @venue, notice: "Speellokatie is toegevoegd."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @venue.update(venue_params)
      redirect_to @venue, notice: "Speellokatie is bijgewerkt."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @venue.destroy!
    redirect_to venues_url, notice: "Speellokatie is verwijderd.", status: :see_other
  end

  private
    def set_venue
      @venue = Venue.find(params[:id])
    end

    def venue_params
      params.expect(venue: [:club_id, :name, :address, :city, :playing_day, :playing_time, :info])
    end
end
