# gocompetitie.nl

Ruby on Rails application for the Dutch Go Competition (Nederlandse Go Competitie).
It is a rebuild of the original [ngc](https://github.com/HermanHiddema/ngc) Rails 4
application on Rails 8, with the same business logic and a new Tailwind CSS frontend.

## Domain

* **Season** – a competition season (e.g. *Voorjaar 2026*). Every season has its own
  path, `/season/voorjaar-2026`, which also prefixes the pages of that season, e.g.
  `/season/voorjaar-2026/teams`. Without a season in the path the most recent season
  is shown. A season is a *draft* while it is being prepared, *active* while it is
  played and *finished* once it is closed. There is at most one active season and the
  front page redirects to it, or to the season that was finished most recently.
  Drafts are only visible to admins, and the results of a finished season can no
  longer be changed: finishing a season records its unplayed games as 0-0. Leagues
  and teams are set up while the season is a draft; once it has started no more of
  them can be added.
* **League** (*poule*) – a group of teams within a season that play a round robin.
* **Club**, **Venue** (*speellocatie*) and **Person** – the organisations, playing
  locations and contact persons. Clubs and venues outlive a season, so their pages
  are prefixed with the season as well and list only what takes part in it.
* **Participant** – a person playing in a specific season, with rating and rank.
* **Team** and **TeamMember** – three players per team, one per board.
* **Match** and **Game** – a match between two teams consists of a game per board.
  Board points are 1 for a win, 0.5 for a jigo; a match is won by the team with the
  most board points. Individual performance is calculated with the EGF rating formula.
  A game can be played with a handicap, which defaults to the rating difference minus
  300, divided by 100 and rounded to the nearest whole number (halves round down).
  The rating calculation counts each handicap stone as 100 rating points for the
  player who receives them.
  Games and matches are stored per side (`home` and `away`), not per color: with a
  handicap the weaker player takes black, otherwise the home team plays black on the
  odd boards and white on the even ones.
* **User** – an account to sign in with. Ordinary users are team captains, who may only
  edit matches (date, time, venue, players and results). Users flagged as `admin`
  maintain everything else.

League and season results can be exported in the tab separated format used by the
European Go Database by requesting the text format, e.g. `/leagues/1.text`.

Pages with personal details, such as player names or the addresses of clubs and
venues, are kept out of search indexes. Indexing is opt in: a controller allows
it with `allow_indexing`, every other page gets a `noindex` robots tag and is
disallowed in `public/robots.txt`.

## Development

Requirements: Ruby (see `.ruby-version`), PostgreSQL and Node-free asset tooling
(Tailwind is compiled through `tailwindcss-rails`).

```bash
bin/setup            # install gems, prepare the database and start the server
bin/rails db:seed    # demo season with clubs, teams and a round robin schedule
bin/dev              # or: run the server together with the Tailwind watcher
```

Local database and application variables are loaded from `.env` by dotenv.
Create it from `.env.example` before running setup if it does not exist:

```bash
cp .env.example .env
```

Rails credentials are encrypted with `config/master.key`, which is ignored by
Git. Keep that key in a password manager and set its value as `RAILS_MASTER_KEY`
in Railway. Add encrypted secrets locally with:

```bash
bin/rails credentials:edit
```

The seeds create an administrator, `admin@example.com` with password `secret123456`,
in the development environment.

## Testing and linting

```bash
bin/rails test       # unit and integration tests
bin/rubocop          # style
bin/brakeman         # static security analysis
```

## Deploying to Railway

The app builds from the included `Dockerfile` and requires its production
configuration through environment variables. Missing required variables make
the application fail during boot:

| Variable | Required | Purpose |
| --- | --- | --- |
| `DATABASE_URL` | yes, unless using the `DB_*` fallback below | Primary Postgres connection string; when the role-specific URLs below are unset, the app derives separate `_cache`, `_queue`, and `_cable` database URLs from it. |
| `CACHE_DATABASE_URL`, `QUEUE_DATABASE_URL`, `CABLE_DATABASE_URL` | no | Optional overrides for the Solid Cache, Queue, and Cable databases. Each must point at a separate database. |
| `DB_HOST`, `DB_NAME`, `DB_USERNAME`, `DB_PASSWORD` | alternative to `DATABASE_URL` | Credentials for deployments that connect without `DATABASE_URL`; `DB_NAME` is used as the base name and the app adds `_cache`, `_queue`, and `_cable` for the non-primary databases. |
| `RAILS_MASTER_KEY` or `SECRET_KEY_BASE` | yes | Decrypts `config/credentials.yml.enc` / signs sessions. |
| `APP_HOST` | yes | Public host used in mailer links. |
| `APP_PROTOCOL` | no | Public protocol used in mailer links (defaults to `https`). |
| `RAILS_ALLOWED_HOSTS` | yes | Comma-separated list of allowed `Host` headers. |
| `COOKIE_DOMAIN` | no | Domain the session cookies are set on (defaults to the registered domain, so that a login on `www` also applies to the apex domain and vice versa). |
| `MAILGUN_API_KEY`, `MAILGUN_DOMAIN` | yes | Mailgun API credentials and sending domain used to deliver email. |
| `MAILGUN_API_HOST` | no | Mailgun API host (defaults to `api.mailgun.net`, use `api.eu.mailgun.net` for the EU region). |
| `MAILER_FROM_ADDRESS` | yes | From-address for password reset emails. |
| `SOLID_QUEUE_IN_PUMA` | yes | Set to `true` to run the Solid Queue worker inside the web process. |
| `SOLID_QUEUE_DISPATCHER_POLLING_INTERVAL`, `SOLID_QUEUE_DISPATCHER_BATCH_SIZE`, `SOLID_QUEUE_THREADS`, `JOB_CONCURRENCY`, `SOLID_QUEUE_WORKER_POLLING_INTERVAL` | no | Solid Queue worker configuration (defaults: `1`, `500`, `3`, `1`, `1`). |
| `PORT` | auto-set | Railway's public port. |
| `TARGET_PORT` | no | Puma's internal port (defaults to `3000`). |
| `RAILS_MAX_THREADS` | no | Puma/database thread count (defaults to `3`). |
| `RAILS_LOG_LEVEL` | no | Rails log level (defaults to `info`). |
