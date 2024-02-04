class CreateMensaTableViews < ActiveRecord::Migration[7.1]
  def change
    create_table :mensa_table_views, id: :uuid do |t|
      t.string :table_name
      t.string :name
      t.jsonb :data

      t.references :user, null: true, foreign_key: true, type: :uuid

      t.timestamps
    end
    add_index :mensa_table_views, :table_name, unique: false
    add_index :mensa_table_views, :data, using: :gin
  end
end
