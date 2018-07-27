class LoanInterest < ActiveRecord::Base
  monetize 	:amount_cents, with_model_currency: :amount_currency
end
