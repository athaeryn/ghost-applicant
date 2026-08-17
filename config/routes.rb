Rails.application.routes.draw do
  root "pages#home"

  resources :posts, only: %i[index show]
  resources :projects, only: %i[index show]
  resources :roles, only: %i[index show]

  get "tags/:taxonomy", to: "tags#index", as: :taxonomy_tags
  get "tags/:taxonomy/:slug", to: "tags#show", as: :tag

  # The app's embedded Model Context Protocol server (streamable HTTP).
  mount MCP::Server::Transports::StreamableHTTPTransport.new(MCP_SERVER) => "/mcp"

  get "up" => "rails/health#show", as: :rails_health_check
end
