class AddArchivedReasonToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :archived_reason, :string
  end
end
