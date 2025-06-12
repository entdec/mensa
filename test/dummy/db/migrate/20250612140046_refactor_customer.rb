class RefactorCustomer < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :stock_symbol, :string
    add_column :customers, :country, :string
    add_column :customers, :isin, :string
  end
end
