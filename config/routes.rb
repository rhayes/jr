Rails.application.routes.draw do
  resources :weeks
  get 'weeks/index'

  get 'weeks/show'

  get 'weeks/edit'

  get 'weeks/create'

  get 'weeks/update'

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
