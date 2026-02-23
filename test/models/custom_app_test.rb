require "test_helper"

class CustomAppTest < ActiveSupport::TestCase
  setup do
    @agent = agents(:one)
    @account = accounts(:one)
  end

  test "valid custom app" do
    app = CustomApp.new(agent: @agent, account: @account, slug: "my-app", description: "Test", path: "apps/test")
    assert app.valid?
  end

  test "requires slug" do
    app = CustomApp.new(agent: @agent, account: @account, path: "apps/test")
    assert_not app.valid?
    assert_includes app.errors[:slug], "can't be blank"
  end

  test "requires name" do
    app = CustomApp.new(agent: @agent, account: @account, path: "apps/test")
    assert_not app.valid?
    assert_includes app.errors[:name], "can't be blank"
  end

  test "requires path" do
    app = CustomApp.new(agent: @agent, account: @account, slug: "my-app")
    assert_not app.valid?
    assert_includes app.errors[:path], "can't be blank"
  end

  test "slug format validation" do
    invalid_slugs = [ "MyApp", "my app", "1app", "-app", "App!", "MY_APP" ]
    invalid_slugs.each do |slug|
      app = CustomApp.new(agent: @agent, account: @account, slug: slug, path: "apps/test")
      assert_not app.valid?, "Expected '#{slug}' to be invalid"
    end
  end

  test "valid slug formats" do
    valid_slugs = [ "my-app", "app1", "a", "my-cool-app-2" ]
    valid_slugs.each do |slug|
      app = CustomApp.new(agent: @agent, account: @account, slug: slug, path: "apps/test")
      assert app.valid?, "Expected '#{slug}' to be valid: #{app.errors.full_messages}"
    end
  end

  test "slug uniqueness scoped to account" do
    CustomApp.create!(agent: @agent, account: @account, slug: "unique-app", path: "apps/test")
    duplicate = CustomApp.new(agent: @agent, account: @account, slug: "unique-app", path: "apps/other")
    assert_not duplicate.valid?
  end

  test "same slug allowed in different accounts" do
    CustomApp.create!(agent: @agent, account: @account, slug: "shared-slug", path: "apps/test")
    other_app = CustomApp.new(agent: agents(:two), account: accounts(:two), slug: "shared-slug", path: "apps/test")
    assert other_app.valid?
  end

  test "auto-sets name from slug on create" do
    app = CustomApp.new(agent: @agent, account: @account, slug: "my-cool-app", path: "apps/test")
    app.valid?
    assert_equal "My Cool App", app.name
  end

  test "does not override explicit name" do
    app = CustomApp.new(agent: @agent, account: @account, slug: "my-app", name: "Custom Name", path: "apps/test")
    app.valid?
    assert_equal "Custom Name", app.name
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
    app = CustomApp.new(agent: @agent, slug: "test-default", path: "apps/test")
    app.valid?
    assert_equal @account, app.account
  end
end
