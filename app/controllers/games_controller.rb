class GamesController < ApplicationController
  allow_unauthenticated_access only: :index

  def index
    @games = @season ? @season.games.includes(:home_player, :away_player, match: [{ league: :season }, :home_team, :away_team]) : Game.none

    respond_to do |format|
      format.html
      format.text { render plain: rated_games_report }
    end
  end

  private
    def rated_games_report
      @games.select(&:rated?).map do |game|
        [
          game.black_player.firstname, game.black_player.lastname,
          game.white_player.firstname, game.white_player.lastname,
          game.black_result
        ].join(" ")
      end.join("\n")
    end
end
