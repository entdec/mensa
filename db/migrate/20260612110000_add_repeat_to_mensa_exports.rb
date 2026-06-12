class AddRepeatToMensaExports < ActiveRecord::Migration[7.1]
  def change
    add_column :mensa_exports, :repeat, :string, null: false, default: ""
    add_column :mensa_exports, :last_repeat_run_at, :datetime
    add_index :mensa_exports, :repeat
    add_index :mensa_exports, :last_repeat_run_at
  end
end
