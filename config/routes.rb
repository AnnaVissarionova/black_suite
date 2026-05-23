Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations',
    passwords: 'users/passwords'
  }

  resources :projects do
    member do
      patch :update_sharing, to: 'projects#update_sharing'
      post :regenerate_token
      delete :disable_sharing
      get :sharing, defaults: { format: :json }
      get 'experiment/:experiment_id', to: 'projects#show_experiment', as: :experiment_view
    end

    resources :experiments do
      member do
        get :download_json
        patch :update_sharing, to: 'experiments#update_sharing'
        post :regenerate_token
        delete :disable_sharing
        get :sharing, defaults: { format: :json }
        get 'update_plot_data'
      end
    end
  end

  # API для добавления результата эксперимента
  post 'api/add_experiment_result', to: 'projects#api_add_experiment_result'

  # Маршруты для доступа по share_token
  get 'shared/project/:share_token', to: 'projects#show', as: :shared_project
  get 'shared/experiment/:share_token', to: 'experiments#show', as: :shared_experiment
  get 'shared/project/:share_token/experiment/:experiment_id', to: 'projects#show_experiment', defaults: { partial: true }

  get "up" => "rails/health#show", as: :rails_health_check
  root 'projects#index'
end
