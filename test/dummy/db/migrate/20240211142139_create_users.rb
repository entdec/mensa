class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users, id: :uuid do |t|
      t.string :first_name
      t.string :last_name
      t.string :email
      t.references :customer, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end
  end
end
