namespace :grid do
  desc "Create initial admin account (interactive or via env vars)"
  task setup: :environment do
    if User.any?
      puts "Setup already complete — users exist, skipping."
      next
    end

    email = ENV["ADMIN_EMAIL"]
    password = ENV["ADMIN_PASSWORD"]
    first_name = ENV["ADMIN_FIRST_NAME"]
    last_name = ENV["ADMIN_LAST_NAME"]

    interactive = $stdin.respond_to?(:raw) && $stdin.isatty

    if interactive && email.blank?
      puts "\n==> The Grid Setup\n\n"

      print "Admin email: "
      email = $stdin.gets&.strip

      print "Admin password (min 8 chars): "
      password = $stdin.gets&.strip

      print "First name: "
      first_name = $stdin.gets&.strip

      print "Last name: "
      last_name = $stdin.gets&.strip
    end

    if email.blank? || password.blank?
      puts "No ADMIN_EMAIL/ADMIN_PASSWORD set and no users exist."
      puts "Set these environment variables or run this task interactively."
      next
    end

    first_name = "Admin" if first_name.blank?
    last_name = "User" if last_name.blank?

    account = Account.create!(name: "The Grid")
    account.users.create!(
      email_address: email,
      password: password,
      password_confirmation: password,
      first_name: first_name,
      last_name: last_name,
      role: :admin
    )

    puts "Admin account created for #{email}"
  end
end
