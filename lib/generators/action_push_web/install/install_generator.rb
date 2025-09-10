class ActionPushWeb::InstallGenerator < Rails::Generators::Base
  source_root File.expand_path("templates", __dir__)

  def copy_files
    template "app/models/application_push_subscription.rb"
    template "app/models/application_push_web_notification.rb"
    template "app/jobs/application_push_web_notification_job.rb"
    template "config/push.yml"
    template "app/views/pwa/service_worker.js"
    route "mount ActionPushWeb::Engine => \"/action_push_web\""

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
