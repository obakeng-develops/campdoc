class RemoveManagedColumnsFromUsers < ActiveRecord::Migration[8.1]
  def up
    remove_column :users, :plan, :string
    remove_column :users, :send_usage_month, :date
    remove_column :users, :send_usage_count, :integer
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "managed plan and usage data cannot be restored"
  end
end
