class AddUniqueIndex < ActiveRecord::Migration[8.1]
  def change
    add_index :action_push_web_subscriptions,
      [ :owner_type, :owner_id, :endpoint ], unique: true
  end
end
