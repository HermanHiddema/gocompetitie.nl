Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  resources :passwords, param: :token, only: %i[new create edit update]

  resources :leagues, except: :index
  resources :people
  resources :seasons, param: :slug, path: "season"

  # The pages that show the results of a season are addressed with the season
  # slug, e.g. /season/voorjaar-2026/teams. Without a slug the most recent
  # season is shown. Clubs and venues have no season of their own, so all of
  # their pages carry the slug to stay within the season being viewed.
  scope "(season/:season_slug)" do
    resources :clubs
    resources :venues
    resources :games, only: :index
    resources :matches, only: :index
    resources :participants, only: :index
    resources :teams, only: :index
  end

  resources :matches, except: :index
  resources :participants, except: :index
  resources :teams, except: :index

  get "club", to: redirect("/clubs")

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  root "seasons#front"
end
