class AddDescriptionToTableView < ActiveRecord::Migration[8.0]
  def change
    add_column :mensa_table_views, :description, :string
    rename_column :mensa_table_views, :data, :config
  end
end
