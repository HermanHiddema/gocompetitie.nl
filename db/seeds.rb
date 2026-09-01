# Demo data for development: one season with two leagues, six teams and a
# scheduled round robin.
season = Season.find_or_create_by!(name: "Voorjaar #{Date.today.year}") do |record|
  record.information = "Welkom bij de Nederlandse Go Competitie."
end

CLUBS = {
  "Amsterdam" => { abbrev: "Amst", day: 2, time: "20:00", address: "Da Costakade 158", city: "Amsterdam" },
  "Utrecht" => { abbrev: "Utre", day: 1, time: "19:30", address: "Oudegracht 245", city: "Utrecht" },
  "Rotterdam" => { abbrev: "Rott", day: 3, time: "20:00", address: "Coolsingel 30", city: "Rotterdam" },
  "Den Haag" => { abbrev: "Haag", day: 4, time: "19:30", address: "Prinsegracht 27", city: "Den Haag" },
  "Groningen" => { abbrev: "Gron", day: 2, time: "20:00", address: "Oude Kijk in het Jatstraat 5", city: "Groningen" },
  "Eindhoven" => { abbrev: "Eind", day: 5, time: "20:00", address: "Stratumsedijk 20", city: "Eindhoven" }
}.freeze

clubs = CLUBS.map do |name, attributes|
  club = Club.find_or_create_by!(name: "Go Club #{name}") { |record| record.abbrev = attributes[:abbrev] }

  Venue.find_or_create_by!(club: club, name: "Speellokaal #{name}") do |venue|
    venue.address = attributes[:address]
    venue.city = attributes[:city]
    venue.playing_day = attributes[:day]
    venue.playing_time = attributes[:time]
  end

  club
end

season.create_leagues(2) if season.leagues.none?

clubs.each_with_index do |club, index|
  league = season.leagues.ordered[index / 3]
  captain = Person.find_or_create_by!(firstname: "Captain", lastname: club.name) do |person|
    person.club = club
    person.email = "captain-#{club.abbrev.downcase}@example.com"
  end
  club.update!(contact_person: captain)

  team = Team.find_or_create_by!(name: club.name, league: league) do |record|
    record.abbrev = club.abbrev
    record.club = club
    record.captain = captain
  end

  3.times do |board|
    participant = Participant.find_or_create_by!(season: season, firstname: "Speler #{board + 1}", lastname: club.name) do |record|
      record.club = club
      record.rating = 2100 - 100 * index - 50 * board
      record.rank = "#{board + 1}d"
    end

    TeamMember.find_or_create_by!(team: team, board_number: board + 1) { |member| member.participant = participant }
  end
end

season.leagues.each { |league| league.make_pairing if league.matches.none? }

if Rails.env.development?
  User.find_or_create_by!(email_address: "admin@example.com") do |user|
    user.password = "secret123456"
    user.admin = true
    user.save
  end
end
