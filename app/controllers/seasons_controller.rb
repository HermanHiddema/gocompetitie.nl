class SeasonsController < ApplicationController
  before_action :set_season, only: %i[ show edit update destroy ]
  before_action :require_admin!, only: %i[ new create edit update destroy ]

  def index
    @seasons = Season.recent
  end

  def show
    respond_to do |format|
      format.html { redirect_to leagues_url }
      format.text { render plain: @season.results.join("\n") }
    end
  end

  def new
    @season = Season.new
  end

  def edit
  end

  def create
    @season = Season.new(season_params)

    if @season.save
      redirect_to @season, notice: "Seizoen is toegevoegd."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @season.update(season_params)
      redirect_to @season, notice: "Seizoen is bijgewerkt."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @season.destroy!
    redirect_to seasons_url, notice: "Seizoen is verwijderd.", status: :see_other
  end

  private
    def set_season
      @season = Season.find(params[:id])
    end

    def season_params
      params.expect(season: [ :name, :information ])
    end
end
