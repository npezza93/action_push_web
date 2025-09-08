module ActionPushWeb
  class Subscription < ApplicationRecord
    belongs_to :owner, polymorphic: true, optional: true
  end
end
