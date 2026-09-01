class GamesController < ApplicationController
  def index
    @games = @season.games.includes(:black_player, :white_player, match: %i[ black_team white_team ])

    respond_to do |format|
      format.html
      format.text { render plain: rated_games_report }
    end
  end

  private
    def rated_games_report
      @games.select(&:played?).reject(&:forfeit?).map do |game|
        [
          game.black_player.firstname, game.black_player.lastname,
          game.white_player.firstname, game.white_player.lastname,
          game.black_score == 1 ? "+" : "-"
        ].join(" ")
      end.join("\n")
    end
end
