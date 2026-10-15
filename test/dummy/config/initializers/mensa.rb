Mensa.setup do |config|
  config.base_controller = "::ApplicationController"
  config.row_actions_position = :front
  config.search = :fuzzy

  # CustomerUsersTable needs params[:customer_id], give it one for
  # `rails app:mensa:verify_all`. Not in tests, they check it fails without.
  unless Rails.env.test?
    config.verifier_context = ->(table_class) {
      {params: {customer_id: Customer.first&.id}} if table_class == CustomerUsersTable
    }
  end
end
