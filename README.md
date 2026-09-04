# gocompetitie.nl

Ruby on Rails application for the Dutch Go Competition (Nederlandse Go Competitie).
It is a rebuild of the original [ngc](https://github.com/HermanHiddema/ngc) Rails 4
application on Rails 8, with the same business logic and a new Tailwind CSS frontend.

## Domain

* **Season** – a competition season (e.g. *Voorjaar 2026*). Every season has its own
  subdomain, `voorjaar-2026.gocompetitie.nl`; without a matching subdomain the most
  recent season is shown.
* **League** (*poule*) – a group of teams within a season that play a round robin.
* **Club**, **Venue** (*speellokatie*) and **Person** – the organisations, playing
  locations and contact persons.
* **Participant** – a person playing in a specific season, with rating and rank.
* **Team** and **TeamMember** – three players per team, one per board.
* **Match** and **Game** – a match between two teams consists of a game per board.
  Board points are 1 for a win, 0.5 for a jigo; a match is won by the team with the
  most board points. Individual performance is calculated with the EGF rating formula.

League and season results can be exported in the tab separated format used by the
European Go Database by requesting the text format, e.g. `/leagues/1.text`.

## Development

Requirements: Ruby (see `.ruby-version`), PostgreSQL and Node-free asset tooling
(Tailwind is compiled through `tailwindcss-rails`).

```bash
bin/setup            # install gems, prepare the database and start the server
bin/rails db:seed    # demo season with clubs, teams and a round robin schedule
bin/dev              # or: run the server together with the Tailwind watcher
```

The seeds create an administrator, `admin@example.com` with password `secret123456`,
in the development environment.

## Testing and linting

```bash
bin/rails test       # unit and integration tests
bin/rubocop          # style
bin/brakeman         # static security analysis
```
