require "test_helper"

class Agent::Tools::RegisterAppTest < ActiveSupport::TestCase
  setup do
    @agent = agents(:one)
  end

  test "registers a new app" do
    result = Agent::Tools::RegisterApp.new(
      agent: @agent,
      arguments: {
        "slug" => "test-app",
        "description" => "A test app",
        "path" => "apps/test"
      }
    ).call

    assert_match /Registered app/, result
    assert @agent.custom_apps.find_by(slug: "test-app")
  end

  test "updates existing app" do
    Agent::Tools::RegisterApp.new(
      agent: @agent,
      arguments: { "slug" => "update-me", "description" => "V1", "path" => "apps/v1" }
    ).call

    Agent::Tools::RegisterApp.new(
      agent: @agent,
      arguments: { "slug" => "update-me", "description" => "V2", "path" => "apps/v2" }
    ).call

    app = @agent.custom_apps.find_by(slug: "update-me")
    assert_equal "V2", app.description
    assert_equal "apps/v2", app.path
  end

  test "requires slug" do
    result = Agent::Tools::RegisterApp.new(
      agent: @agent,
      arguments: { "description" => "Test", "path" => "apps/test" }
    ).call

    assert_match /Error/, result
  end

  test "requires description" do
    result = Agent::Tools::RegisterApp.new(
      agent: @agent,
      arguments: { "slug" => "test", "path" => "apps/test" }
    ).call

    assert_match /Error/, result
  end

  test "requires path" do
    result = Agent::Tools::RegisterApp.new(
      agent: @agent,
      arguments: { "slug" => "test", "description" => "Test" }
    ).call

    assert_match /Error/, result
  end

  test "sets default entrypoint" do
    Agent::Tools::RegisterApp.new(
      agent: @agent,
      arguments: { "slug" => "default-entry", "description" => "Test", "path" => "apps/test" }
    ).call

    app = @agent.custom_apps.find_by(slug: "default-entry")
    assert_equal "index.html", app.entrypoint
  end

  test "custom entrypoint" do
    Agent::Tools::RegisterApp.new(
      agent: @agent,
      arguments: { "slug" => "custom-entry", "description" => "Test", "path" => "apps/test", "entrypoint" => "app.html" }
    ).call

    app = @agent.custom_apps.find_by(slug: "custom-entry")
    assert_equal "app.html", app.entrypoint
  end

  test "sets icon emoji" do
    Agent::Tools::RegisterApp.new(
      agent: @agent,
      arguments: { "slug" => "emoji-app", "description" => "Test", "path" => "apps/test", "icon_emoji" => "🎯" }
    ).call

    app = @agent.custom_apps.find_by(slug: "emoji-app")
    assert_equal "🎯", app.icon_emoji
  end

  test "defaults name from slug" do
    Agent::Tools::RegisterApp.new(
      agent: @agent,
      arguments: { "slug" => "my-cool-app", "description" => "Test", "path" => "apps/test" }
    ).call

    app = @agent.custom_apps.find_by(slug: "my-cool-app")
    assert_equal "My Cool App", app.name
  end

  test "accepts explicit name" do
    Agent::Tools::RegisterApp.new(
      agent: @agent,
      arguments: { "slug" => "named-app", "name" => "Custom Name", "description" => "Test", "path" => "apps/test" }
    ).call

    app = @agent.custom_apps.find_by(slug: "named-app")
    assert_equal "Custom Name", app.name
  end
end
