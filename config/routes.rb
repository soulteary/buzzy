Rails.application.routes.draw do
  root "events#index"

  namespace :account do
    resource :cancellation, only: [ :create ]
    resource :entropy
    resource :settings, only: :show
    resources :exports, only: [ :create, :show ]
    resources :imports, only: [ :new, :create, :show ]
  end

  post "follow/:user_id", to: "users#follow", as: :follow_user
  delete "unfollow/:user_id", to: "users#unfollow", as: :unfollow_user

  resources :users, path: "users" do
    get "profile", action: :profile, on: :member, as: :profile
    get "boards", to: "users/boards#index", on: :member, as: :boards
    get "cards", to: "users/cards#index", on: :member, as: :cards

    resources :boards, only: [ :show, :edit, :update ], controller: "boards", param: :id do
      scope module: :boards do
        resource :involvement
        resource :entropy
        namespace :columns do
          resource :not_now
          resource :stream
          resource :closed
        end
        resources :columns, constraints: { id: /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i }
      end
      resources :columns, only: [] do
        resource :left_position, module: :columns, only: :create
        resource :right_position, module: :columns, only: :create
      end
      namespace :columns do
        resources :cards, only: [] do
          scope module: :cards do
            namespace :drops do
              resource :not_now, only: :create
              resource :stream, only: :create
              resource :closure, only: :create
              resource :column, only: :create
            end
          end
        end
      end
      resources :webhooks, controller: "webhooks" do
        scope module: :webhooks do
          resource :activation, only: :create
        end
      end
      resources :cards, only: [ :create, :show, :edit, :update, :destroy ], controller: "cards", param: :id do
        scope module: :cards do
          resource :draft, only: :show
          resource :board
          resource :closure
          resource :column
          resource :goldness
          resource :image
          resource :not_now
          resource :pin
          resource :publish
          resource :reading
          resource :triage
          resource :watch
          resources :reactions
          resources :assignments
          resource :self_assignment, only: :create
          resources :steps
          resources :taggings
          resources :comments do
            resources :reactions, module: :comments
          end
        end
      end
    end

    scope module: :users do
      resource :avatar
      resource :role
      resource :events

      resources :push_subscriptions

      resources :email_addresses, param: :token do
        resource :confirmation, module: :email_addresses
      end

      resources :data_exports, only: [ :create, :show ]
    end
  end

  resources :boards, only: [ :index, :new, :create ]

  resources :columns, only: [] do
    resource :left_position, module: :columns
    resource :right_position, module: :columns
  end

  namespace :columns do
    resources :cards do
      scope module: :cards do
        namespace :drops do
          resource :not_now
          resource :stream
          resource :closure
          resource :column
        end
      end
    end
  end

  namespace :cards do
    resources :previews
  end

  get "cards", to: "cards#index", as: :cards

  resources :tags, only: :index

  namespace :notifications do
    resource :settings
    resource :unsubscribe
  end

  resources :notifications do
    scope module: :notifications do
      get "tray", to: "trays#show", on: :collection

      resource :reading
      collection do
        resource :bulk_reading, only: :create
      end
    end
  end

  resource :search
  namespace :searches do
    resources :queries
  end

  resources :filters do
    scope module: :filters do
      collection do
        resource :settings_refresh, only: :create
      end
    end
  end

  resources :events, only: :index
  namespace :events do
    resources :days
    namespace :day_timeline do
      resources :columns, only: :show
    end
  end

  resources :qr_codes

  resource :session do
    scope module: :sessions do
      resources :transfers
      resource :magic_link
      resource :menu
    end
  end

  get "/signup", to: redirect("/signup/new")

  resource :signup, only: %i[ new create ] do
    collection do
      scope module: :signups, as: :signup do
        resource :completion, only: %i[ new create ]
      end
    end
  end

  resource :landing

  # Join-by-code (invite to existing account) removed for single-user-per-account architecture
  # get "join", to: "join_codes#new", as: :join
  # post "join", to: "join_codes#create"

  namespace :my do
    resource :identity, only: :show
    resource :locale, only: :update
    resource :session_transfer, only: :update
    resources :access_tokens
    resources :pins
    resource :timezone
    resource :menu
  end

  namespace :prompts do
    resources :cards
    resources :tags
    resources :users

    resources :boards do
      scope module: :boards do
        resources :users
      end
    end
  end

  resolve "Comment" do |comment, options|
    options[:anchor] = ActionView::RecordIdentifier.dom_id(comment)
    route_for :user_board_card, comment.card.board.url_user, comment.card.board, comment.card, options
  end

  resolve "Mention" do |mention, options|
    polymorphic_url(mention.source, options)
  end

  resolve "Notification" do |notification, options|
    polymorphic_url(notification.notifiable_target, options)
  end

  resolve "Event" do |event, options|
    polymorphic_url(event.eventable, options)
  end

  resolve "Webhook" do |webhook, options|
    route_for :user_board_webhook, webhook.board.url_user, webhook.board, webhook, options
  end

  resolve "User" do |user, options|
    route_for :user, user, options
  end

  resolve "Board" do |board, options|
    route_for :user_board, board.url_user, board, options
  end

  resolve "Card" do |card, options|
    route_for :user_board_card, card.board.url_user, card.board, card, options
  end

  get "up", to: "rails/health#show", as: :rails_health_check
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "pwa#service_worker"

  namespace :square do
    get "all_content", to: "all_content#index", as: :all_content
    get "following", to: "following#index", as: :following
  end

  namespace :admin do
    get "all_content", to: "all_content#index", as: :all_content
    match "boards/:id/toggle_visibility_lock", to: "boards#toggle_visibility_lock", as: :board_toggle_visibility_lock, via: [ :patch, :post ]
    match "boards/:id/toggle_edit_lock", to: "boards#toggle_edit_lock", as: :board_toggle_edit_lock, via: [ :patch, :post ]
    patch "users/:id/freeze", to: "users#freeze", as: :user_freeze
    patch "users/:id/unfreeze", to: "users#unfreeze", as: :user_unfreeze
    mount MissionControl::Jobs::Engine, at: "/jobs"
  end
end
