require "test_helper"

class CustomAppTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @agent = agents(:one)
    @account = accounts(:one)
  end

  test "valid custom app" do
    app = CustomApp.new(agent: @agent, account: @account, slug: "my-app", description: "Test")
    assert app.valid?
  end

  test "requires slug" do
    app = CustomApp.new(agent: @agent, account: @account)
    assert_not app.valid?
    assert_includes app.errors[:slug], "can't be blank"
  end

  test "requires name" do
    app = CustomApp.new(agent: @agent, account: @account)
    assert_not app.valid?
    assert_includes app.errors[:name], "can't be blank"
  end

  test "path is auto-set from slug" do
    app = CustomApp.new(agent: @agent, account: @account, slug: "my-app")
    app.valid?
    assert_equal "apps/my-app", app.path
  end

  test "slug format validation" do
    invalid_slugs = [ "MyApp", "my app", "1app", "-app", "App!", "MY_APP" ]
    invalid_slugs.each do |slug|
      app = CustomApp.new(agent: @agent, account: @account, slug: slug)
      assert_not app.valid?, "Expected '#{slug}' to be invalid"
    end
  end

  test "valid slug formats" do
    valid_slugs = [ "my-app", "app1", "a", "my-cool-app-2" ]
    valid_slugs.each do |slug|
      app = CustomApp.new(agent: @agent, account: @account, slug: slug)
      assert app.valid?, "Expected '#{slug}' to be valid: #{app.errors.full_messages}"
    end
  end

  test "slug uniqueness scoped to account" do
    CustomApp.create!(agent: @agent, account: @account, slug: "unique-app")
    duplicate = CustomApp.new(agent: @agent, account: @account, slug: "unique-app")
    assert_not duplicate.valid?
  end

  test "same slug allowed in different accounts" do
    CustomApp.create!(agent: @agent, account: @account, slug: "shared-slug")
    other_app = CustomApp.new(agent: agents(:two), account: accounts(:two), slug: "shared-slug")
    assert other_app.valid?
  end

  test "auto-sets name from slug on create" do
    app = CustomApp.new(agent: @agent, account: @account, slug: "my-cool-app")
    app.valid?
    assert_equal "My Cool App", app.name
  end

  test "does not override explicit name" do
    app = CustomApp.new(agent: @agent, account: @account, slug: "my-app", name: "Custom Name")
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
    app = CustomApp.new(agent: @agent, slug: "test-default")
    app.valid?
    assert_equal @account, app.account
  end

  test "storage_path points to independent storage" do
    app = custom_apps(:slideshow)
    assert app.storage_path.to_s.start_with?(Rails.root.join("storage", "apps", app.id.to_s).to_s)
  end

  test "files_path is under storage_path" do
    app = custom_apps(:slideshow)
    assert_equal app.storage_path.join("files"), app.files_path
  end

  test "database_path is under storage_path" do
    app = custom_apps(:slideshow)
    assert_equal app.storage_path.join("data.db"), app.database_path
  end

  test "creates files directory after create" do
    app = CustomApp.create!(agent: @agent, account: @account, slug: "dir-test", description: "Test")
    assert app.files_path.exist?
  ensure
    FileUtils.rm_rf(app.storage_path) if app&.persisted?
  end

  test "enqueues storage cleanup on destroy" do
    app = CustomApp.create!(agent: @agent, account: @account, slug: "cleanup-test", description: "Test")
    assert app.storage_path.exist?

    assert_enqueued_with(job: CleanupAppStorageJob) do
      app.destroy!
    end

    perform_enqueued_jobs
    assert_not app.storage_path.exist?
  end
end
