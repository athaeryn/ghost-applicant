Rails.application.routes.draw do
  root "pages#home"

  resources :posts, only: %i[index show]
  resources :projects, only: %i[index show]
  resources :roles, only: %i[index show]
  resources :job_applications, only: %i[index show] do
    member do
      post :add_tag
      delete :remove_tag
    end
  end

  get "tags/:taxonomy", to: "tags#index", as: :taxonomy_tags
  get "tags/:taxonomy/:slug", to: "tags#show", as: :tag

  namespace :admin do
    get "/", to: "dashboard#index"
    resources :posts
    resources :projects
    resources :roles
    resources :job_applications
    resources :taxonomies, only: %i[index new create show destroy]
    resources :tags, only: %i[create destroy]
  end

  # The app's embedded Model Context Protocol server (streamable HTTP).
  mount MCP::Server::Transports::StreamableHTTPTransport.new(MCP_SERVER) => "/mcp"

  get "up" => "rails/health#show", as: :rails_health_check
end
