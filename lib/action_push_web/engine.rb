module ActionPushWeb
  class Engine < ::Rails::Engine
    isolate_namespace ActionPushWeb
    config.autoload_once_paths = %W[
      #{root}/app/helpers
    ]

    config.action_push_web = ActiveSupport::OrderedOptions.new

    initializer "action_push_web.config" do |app|
      app.paths.add "config/push", with: "config/push.yml"
    end

    initializer "action_push_web.pool" do |app|
      at_exit { ActionPushWeb.pool.shutdown }
    end

    initializer "action_push_web.assets" do
      if Rails.application.config.respond_to?(:assets)
        Rails.application.config.assets.precompile += %w[action_push_web.js]
      end
    end

    initializer "action_push_web.importmap", before: "importmap" do |app|
      if Rails.application.respond_to?(:importmap)
        app.config.importmap.paths << Engine.root.join("config/importmap.rb")
      end
    end

    initializer "action_push_web.helpers", before: :load_config_initializers do
      ActiveSupport.on_load(:action_controller_base) do
        helper ActionPushWeb::Engine.helpers
      end
    end
  end
end
