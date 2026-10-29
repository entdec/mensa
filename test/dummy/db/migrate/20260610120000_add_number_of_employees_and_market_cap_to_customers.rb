class AddNumberOfEmployeesAndMarketCapToCustomers < ActiveRecord::Migration[8.1]
  def change
    add_column :customers, :number_of_employees, :integer
    add_column :customers, :market_cap, :bigint
  end
end
