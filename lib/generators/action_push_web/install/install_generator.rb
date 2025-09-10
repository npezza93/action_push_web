class ActionPushWeb::InstallGenerator < Rails::Generators::Base
  source_root File.expand_path("templates", __dir__)

  APPLICATION_LAYOUT_PATH = Rails.root.join("app/views/layouts/application.html.erb")

  def copy_files
    template "app/models/application_push_subscription.rb"
    template "app/models/application_push_web_notification.rb"
    template "app/jobs/application_push_web_notification_job.rb"
    template "app/views/pwa/service-worker.js"
    route "mount ActionPushWeb::Engine => \"/action_push_web\""

    if Rails.root.join("config/push.yml").exist?
      append_to_file "config/push.yml", File.read("#{self.class.source_root}/config/push.yml.tt").split("\n")[1..].join("\n").prepend("\n")
    else
      template "config/push.yml"
    end

    if Rails.root.join("app/javascript/application.js").exist?
      append_to_file "app/javascript/application.js", %(import "action_push_web"\n)
    end

    if Rails.root.join("package.json").exist? && Rails.root.join("bun.config.js").exist?
      # run "bun add action_push_web"
    elsif Rails.root.join("package.json").exist?
      # run "yarn add action_push_web"
    end

    if APPLICATION_LAYOUT_PATH.exist?
      say "Add action push web meta tag in application layout"
      insert_into_file APPLICATION_LAYOUT_PATH.to_s, "\n    <%= action_push_web_key_tag %>", before: /\s*<\/head>/
    else
      say "Default application.html.erb is missing!", :red
      say "        Add <%= action_push_web_key_tag %> within the <head> tag in your custom layout."
    end

    rails_command "railties:install:migrations FROM=action_push_web",
      inline: true

    vapid_key = ActionPushWeb::VapidKeyGenerator.new

    puts "\n"
    puts <<~MSG
      Add this entry to the credentials of the target environment:#{' '}

      action_push_web:
        public_key: #{vapid_key.public_key}
        private_key: #{vapid_key.private_key}
    MSG
  end
end
