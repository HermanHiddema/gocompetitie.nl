namespace :egd do
  desc "Seed a season with players from the European Go Database (SEASON=slug COUNTRY=NL YEARS=4)"
  task import_players: :environment do
    season = if ENV["SEASON"].present?
      Season.find_by!(slug: ENV["SEASON"])
    else
      Season.with_slug.draft.recent.first or abort "Geen draftseizoen gevonden, geef er een op met SEASON=slug."
    end

    country_code = ENV["COUNTRY"].presence || Season::EGD_COUNTRY_CODE
    years = ENV["YEARS"].presence || Season::EGD_ACTIVE_YEARS

    imported = season.import_egd_players(country_code: country_code, years: years)
    puts "#{imported} spelers uit #{country_code} geïmporteerd in #{season.name}."
  rescue Egd::Error => error
    abort error.message
  rescue ActiveRecord::RecordInvalid => error
    abort error.record.errors.full_messages.to_sentence
  end
end
