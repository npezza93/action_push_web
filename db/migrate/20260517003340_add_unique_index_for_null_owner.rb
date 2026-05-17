class AddUniqueIndexForNullOwner < ActiveRecord::Migration[8.1]
  def change
    add_index :action_push_web_subscriptions, :endpoint, unique: true,
      where: "owner_id IS NULL AND owner_type IS NULL"
  end
end
