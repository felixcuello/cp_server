Rails.application.routes.draw do
  # Devise for users - skip registrations (private server, admins create accounts manually)
  devise_for :users, skip: [:registrations]
  
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  get "/", to: "problem#index", as: "home"

  get "problems", to: "problem#index", as: "problems"
  get "problems/:id", to: "problem#show", as: "problem"
  get "problems/:id/recent_submission", to: "problem#recent_submission", as: "problem_recent_submission"

  get "submissions", to: "submission#index", as: "submission"
  get "submissions/:id", to: "submission#show", as: "submission_detail"
  post "submissions/submit", to: "submission#submit", as: "problem_submission"
  post "submissions/test", to: "submission#test", as: "problem_test"
  get "contests/:contest_id/submissions", to: "submission#contest_submissions", as: "contest_submissions"

  resources :contests, only: [:index, :show] do
    member do
      post :join
      get :standings
      get :submissions
    end
  end

  get 'user/:alias', to: 'user#show', as: 'user'

  # Admin namespace
  namespace :admin do
    resources :contests, controller: 'contest' do
      member do
        post :add_problem
        post :remove_problem
      end
      collection do
        post :toggle_problem_visibility
      end
    end
  end

  require 'sidekiq/web'
  # Protect Sidekiq web UI - only accessible to admin users
  mount Sidekiq::Web => '/sidekiq', constraints: AdminConstraint.new
end
