class CreateMensaExports < ActiveRecord::Migration[7.1]
  def change
    create_table :mensa_exports, id: :uuid do |t|
      t.string :table_name, null: false
      # The view (system or custom) the export was generated for, if applicable.
      t.references :table_view, null: true, type: :uuid, foreign_key: {to_table: :mensa_table_views}

      # Scope ("all" / "current_page") and output format ("csv_excel" / "plain_csv").
      t.string :scope
      t.string :format
      # Lifecycle: pending -> processing -> completed / failed.
      t.string :status, null: false, default: "pending"
      # The request configuration (filters, query, order, page) used to build the export.
      t.jsonb :config, null: false, default: {}
      t.string :filename

      t.references :user, null: true, foreign_key: true, type: :uuid

      t.timestamps
    end

    add_index :mensa_exports, :table_name
    add_index :mensa_exports, :status
  end
end
