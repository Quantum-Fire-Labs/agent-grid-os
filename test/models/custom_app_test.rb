require "test_helper"

class CustomAppTest < ActiveSupport::TestCase
  setup do
    @agent = agents(:one)
    @account = accounts(:one)
  end

  test "valid custom app" do
    app = CustomApp.new(agent: @agent, account: @account, name: "my-app", description: "Test", path: "apps/test")
    assert app.valid?
  end

  test "requires name" do
    app = CustomApp.new(agent: @agent, account: @account, path: "apps/test")
    assert_not app.valid?
    assert_includes app.errors[:name], "can't be blank"
  end

  test "requires path" do
    app = CustomApp.new(agent: @agent, account: @account, name: "my-app")
    assert_not app.valid?
    assert_includes app.errors[:path], "can't be blank"
  end

  test "name format validation" do
    invalid_names = [ "MyApp", "my app", "1app", "-app", "App!", "MY_APP" ]
    invalid_names.each do |name|
      app = CustomApp.new(agent: @agent, account: @account, name: name, path: "apps/test")
      assert_not app.valid?, "Expected '#{name}' to be invalid"
    end
  end

  test "valid name formats" do
    valid_names = [ "my-app", "app1", "a", "my-cool-app-2" ]
    valid_names.each do |name|
      app = CustomApp.new(agent: @agent, account: @account, name: name, path: "apps/test")
      assert app.valid?, "Expected '#{name}' to be valid: #{app.errors.full_messages}"
    end
  end

  test "name uniqueness scoped to account" do
    CustomApp.create!(agent: @agent, account: @account, name: "unique-app", path: "apps/test")
    duplicate = CustomApp.new(agent: @agent, account: @account, name: "unique-app", path: "apps/other")
    assert_not duplicate.valid?
  end

  test "same name allowed in different accounts" do
    CustomApp.create!(agent: @agent, account: @account, name: "shared-name", path: "apps/test")
    other_app = CustomApp.new(agent: agents(:two), account: accounts(:two), name: "shared-name", path: "apps/test")
    assert other_app.valid?
  end

  test "icon_display returns :emoji when emoji set" do
    app = custom_apps(:slideshow)
    app.icon_emoji = "📊"
    assert_equal :emoji, app.icon_display
  end

  test "icon_display returns :initial when no icon" do
    app = custom_apps(:slideshow)
    app.icon_emoji = nil
    assert_equal :initial, app.icon_display
  end

  test "status enum" do
    app = custom_apps(:slideshow)
    assert app.published?

    app.status = "draft"
    assert app.draft?

    app.status = "disabled"
    assert app.disabled?
  end

  test "resolve_asset rejects directory traversal" do
    app = custom_apps(:slideshow)
    assert_nil app.resolve_asset("../../../etc/passwd")
    assert_nil app.resolve_asset("foo/../../bar")
  end

  test "resolve_asset rejects absolute paths" do
    app = custom_apps(:slideshow)
    assert_nil app.resolve_asset("/etc/passwd")
  end

  test "resolve_asset rejects blank path" do
    app = custom_apps(:slideshow)
    assert_nil app.resolve_asset("")
    assert_nil app.resolve_asset(nil)
  end

  test "default account from agent" do
    app = CustomApp.new(agent: @agent, name: "test-default", path: "apps/test")
    app.valid?
    assert_equal @account, app.account
  end
end
