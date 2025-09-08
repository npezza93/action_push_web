class CreateActionPushWebSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :action_push_web_subscriptions do |t|
      t.belongs_to :owner, polymorphic: true
      t.string :endpoint, null: false
      t.string :auth_key, null: false
      t.string :p256dh_key, null: false
      t.string :user_agent

      t.timestamps
    end
  end
end
