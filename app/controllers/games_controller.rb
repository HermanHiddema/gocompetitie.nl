class GamesController < ApplicationController
  allow_unauthenticated_access only: :index

  def index
    @games = @season ? @season.games.includes(:black_player, :white_player, match: %i[black_team white_team]) : Game.none

    respond_to do |format|
      format.html
      format.text { render plain: rated_games_report }
    end
  end

  private
    def rated_games_report
      @games.select { |game| game.played? && game.players? }.reject(&:forfeit?).map do |game|
        [
          game.black_player.firstname, game.black_player.lastname,
          game.white_player.firstname, game.white_player.lastname,
          game.black_result
        ].join(" ")
      end.join("\n")
    end
end
