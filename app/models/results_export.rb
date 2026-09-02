# Builds the tab separated result list that is uploaded to the European Go
# Database. Players are listed in team order, every player line lists the
# opponent number and result of each of their games.
class ResultsExport
  PLAYERS_PER_GROUP = 3

  def initialize(ordered_participants:, games:, group_names: [])
    @groups = ordered_participants.first.is_a?(Array) ? ordered_participants : [ordered_participants]
    @ordered_participants = @groups.flatten.compact.uniq
    @games = games
    @group_names = group_names + ["Reserves"]
  end

  def lines
    grouped_lines = if @groups.length > 1
      offset = 0
      @groups.map do |group|
        result = player_lines[offset, group.length]
        offset += group.length
        result
      end
    else
      player_lines.each_slice(PLAYERS_PER_GROUP).to_a
    end
    grouped_lines.zip(group_names).flat_map do |players, group_name|
      [group_name ? "; #{group_name}" : nil, *players]
    end.compact
  end

  def to_s
    lines.join("\n")
  end

  private
    attr_reader :ordered_participants, :games, :group_names

    def player_lines
      table = results_table
      participants = participants_by_id(table.keys)
      width = table.values.map(&:length).max.to_i

      table.map.with_index do |(participant_id, results), index|
        player_line(participants[participant_id], index + 1, results, width)
      end
    end

    def player_line(participant, number, results, width)
      [
        number,
        format("%-30s", [participant.lastname, participant.firstname].map(&:strip).join(" ")),
        participant.rank,
        "NL",
        participant.club&.abbrev,
        participant.team_member&.board_number || 0,
        format("%.2f", 100 * participant.rating_change),
        results.count { |result| result[:result] == "+" },
        results.map { |result| "#{result[:opponent_number]}#{result[:result]}" },
        Array.new(width - results.length) { "0=" }
      ].flatten.map(&:to_s).join("\t")
    end

    # Every player gets a row of game slots. Both players of a game share the
    # same slot, so the columns line up as rounds.
    def results_table
      table = ordered_participants.to_h { |participant| [participant.id, []] }

      games.each do |game|
        next unless game.played? && game.black_id && game.white_id

        table[game.black_id] ||= []
        table[game.white_id] ||= []

        slot = 0
        slot += 1 while table[game.black_id][slot] || table[game.white_id][slot]
        table[game.black_id][slot] = { game: game, opponent_id: game.white_id, result: game.black_result }
        table[game.white_id][slot] = { game: game, opponent_id: game.black_id, result: game.white_result }
      end

      number_opponents(table)
    end

    def number_opponents(table)
      table.each_with_index do |(participant_id, results), index|
        results.each_with_index do |result, slot|
          if result.nil?
            table[participant_id][slot] = { game: nil, opponent_id: nil, result: "=", opponent_number: 0 }
          else
            table[result[:opponent_id]][slot][:opponent_number] = result[:game].forfeit? ? 0 : index + 1
          end
        end
      end

      table
    end

    def participants_by_id(ids)
      Participant.where(id: ids).includes(:club, :team_member).index_by(&:id)
    end
end
