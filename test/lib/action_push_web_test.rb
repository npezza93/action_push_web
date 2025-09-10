require "test_helper"

class ActionPushWebTest < ActiveSupport::TestCase
  test "config_for application" do
    stub_config("push_web.yml")
    config = ActionPushWeb.config_for nil
    expected_config = { public_key: "public_key", private_key: "private_key" }
    assert_equal expected_config, config
  end

  test "config_for custom notification" do
    stub_config("push_calendar.yml")
    config = ActionPushWeb.config_for :calendar
    expected_config = { ttl: 10, public_key: "cal_public_key", private_key: "cal_private_key" }
    assert_equal expected_config, config
  end

  private
    def stub_config(name)
      Rails.application.stubs(:config_for).returns(YAML.load_file(file_fixture("config/#{name}"), symbolize_names: true))
    end
end
