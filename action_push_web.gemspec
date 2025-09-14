require_relative "lib/action_push_web/version"

Gem::Specification.new do |spec|
  spec.name        = "pezza_action_push_web"
  spec.version     = ActionPushWeb::VERSION
  spec.authors     = [ "Nick Pezza" ]
  spec.email       = [ "pezza@hey.com" ]

  spec.summary = "Send push notifications to web apps"
  spec.description = "Send push notifications to web apps"
  spec.homepage = "https://github.com/npezza93/action_push_web"
  spec.license = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  rails_version = ">= 8.0"
  spec.add_dependency "activerecord", rails_version
  spec.add_dependency "activejob", rails_version
  spec.add_dependency "railties", rails_version
  spec.add_dependency "net-http"
  spec.add_dependency "net-http-persistent"
  spec.add_dependency "jwt"
end
