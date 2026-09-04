Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  resources :passwords, param: :token, only: %i[new create edit update]

  resources :clubs
  resources :games, only: :index
  resources :leagues
  resources :matches
  resources :participants
  resources :people
  resources :seasons
  resources :teams
  resources :venues

  get "club", to: redirect("/clubs")

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  root "leagues#index"
end
