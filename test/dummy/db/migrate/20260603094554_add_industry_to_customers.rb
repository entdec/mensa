class AddIndustryToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :industry, :string
  end
end
