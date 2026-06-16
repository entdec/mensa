class AddPasswordToExport < ActiveRecord::Migration[8.1]
  def change
    add_column :mensa_exports, :password, :string
  end
end
