# frozen_string_literal: true

# User management service for authentication and authorization.
# Handles user creation, authentication, and permission checks.
# Completely unrelated to math/calculation operations.
class UserService
  class AuthenticationError < StandardError; end
  class AuthorizationError < StandardError; end
  class UserNotFoundError < StandardError; end

  attr_reader :users, :sessions

  ROLES = {
    admin: { permissions: [:read, :write, :delete, :admin] },
    editor: { permissions: [:read, :write] },
    viewer: { permissions: [:read] }
  }.freeze

  def initialize
    @users = {}
    @sessions = {}
  end

  def create_user(username:, password:, email:, role: :viewer)
    raise ArgumentError, "Username already exists" if @users.key?(username)
    raise ArgumentError, "Invalid role" unless ROLES.key?(role)

    @users[username] = {
      username: username,
      password_hash: hash_password(password),
      email: email,
      role: role,
      created_at: Time.now.utc,
      last_login: nil
    }
  end

  def authenticate(username:, password:)
    user = @users[username]
    raise UserNotFoundError, "User not found" unless user
    raise AuthenticationError, "Invalid password" unless verify_password(password, user[:password_hash])

    session_token = generate_session_token
    @sessions[session_token] = {
      username: username,
      created_at: Time.now.utc,
      expires_at: Time.now.utc + 3600 # 1 hour
    }

    user[:last_login] = Time.now.utc
    session_token
  end

  def authorize(session_token:, permission:)
    session = @sessions[session_token]
    raise AuthenticationError, "Invalid session" unless session
    raise AuthenticationError, "Session expired" if session[:expires_at] < Time.now.utc

    user = @users[session[:username]]
    role_permissions = ROLES[user[:role]][:permissions]

    unless role_permissions.include?(permission)
      raise AuthorizationError, "Permission denied: #{permission}"
    end

    true
  end

  def logout(session_token)
    @sessions.delete(session_token)
  end

  def get_user(username)
    user = @users[username]
    raise UserNotFoundError, "User not found" unless user

    user.except(:password_hash)
  end

  def update_role(username:, new_role:)
    raise UserNotFoundError, "User not found" unless @users.key?(username)
    raise ArgumentError, "Invalid role" unless ROLES.key?(new_role)

    @users[username][:role] = new_role
  end

  def delete_user(username)
    raise UserNotFoundError, "User not found" unless @users.key?(username)

    # Invalidate all sessions for this user
    @sessions.delete_if { |_, v| v[:username] == username }
    @users.delete(username)
  end

  def list_users
    @users.transform_values { |u| u.except(:password_hash) }
  end

  def active_sessions_count
    cleanup_expired_sessions
    @sessions.size
  end

  
  def hash_password(password)
    # Simple hash for demo - in real app would use bcrypt
    Digest::SHA256.hexdigest("salt_#{password}_pepper")
  end

  def verify_password(password, hash)
    hash_password(password) == hash
  end

  def generate_session_token
    SecureRandom.hex(32)
  end

  def cleanup_expired_sessions
    now = Time.now.utc
    @sessions.delete_if { |_, v| v[:expires_at] < now }
  end
end

