# frozen_string_literal: true

namespace :user do
  desc "Create a new user with generated credentials"
  task :create, [:first_name, :last_name, :email] => :environment do |_t, args|
    # Validate arguments
    if args[:first_name].blank? || args[:last_name].blank? || args[:email].blank?
      puts "❌ Error: All arguments are required"
      puts "Usage: rake user:create[FirstName,LastName,email@example.com]"
      exit 1
    end

    first_name = args[:first_name]
    last_name = args[:last_name]
    email = args[:email]

    # Extract alias from email (everything before @)
    user_alias = email.split("@").first

    # Validate email format
    unless email.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
      puts "❌ Error: Invalid email format"
      exit 1
    end

    # Check if user already exists
    if User.exists?(email: email)
      puts "❌ Error: User with email '#{email}' already exists"
      exit 1
    end

    # Generate secure password
    password = generate_secure_password

    # Create the user
    begin
      user = User.create!(
        first_name: first_name,
        last_name: last_name,
        email: email,
        alias: user_alias,
        password: password,
        password_confirmation: password,
        role: :user
      )

      puts "✅ Usuario creado exitosamente!"
      puts ""
      puts "Hola,"
      puts ""
      puts "Tu usuario para el servidor https://cloud-stack.palermo.edu:35500/ de programación fue creado:"
      puts ""
      puts "Usuario: #{email}"
      puts "Contraseña: #{password}"
      puts ""
      puts "¡Ya podés empezar a programar!"
      puts ""
      puts "Saludos!"
    rescue StandardError => e
      puts "❌ Error creating user: #{e.message}"
      exit 1
    end
  end

  desc "Update user password by email"
  task :update_password, [:email] => :environment do |_t, args|
    # Validate arguments
    if args[:email].blank?
      puts "❌ Error: Email is required"
      puts "Usage: rake user:update_password[email@example.com]"
      exit 1
    end

    email = args[:email]

    # Find user by email
    user = User.find_by(email: email)

    unless user
      puts "❌ Error: User with email '#{email}' not found"
      exit 1
    end

    # Generate new secure password
    password = generate_secure_password

    # Update the user's password
    begin
      user.update!(
        password: password,
        password_confirmation: password
      )

      puts "✅ Contraseña actualizada exitosamente!"
      puts ""
      puts "Hola,"
      puts ""
      puts "Tu password para el servidor https://cloud-stack.palermo.edu:35500/ de programación fue cambiado:"
      puts ""
      puts "Usuario: #{email}"
      puts "Contraseña: #{password}"
      puts ""
      puts "¡Ya podés empezar a programar!"
      puts ""
      puts "Saludos!"
    rescue StandardError => e
      puts "❌ Error updating password: #{e.message}"
      exit 1
    end
  end

  private

  def generate_secure_password
    # Character sets for password generation
    uppercase = ("A".."Z").to_a
    lowercase = ("a".."z").to_a
    digits = ("0".."9").to_a
    symbols = "!@#$%^&*()_+-=[]{}|;:,.<>?".chars

    # Ensure at least one character from each set
    password = [
      uppercase.sample,
      lowercase.sample,
      digits.sample,
      symbols.sample
    ]

    # Fill remaining 12 characters randomly from all sets
    all_chars = uppercase + lowercase + digits + symbols
    password += Array.new(12) { all_chars.sample }

    # Shuffle to avoid predictable pattern
    password.shuffle.join
  end
end
