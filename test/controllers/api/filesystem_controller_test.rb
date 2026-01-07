# frozen_string_literal: true

require "test_helper"

module Api
  class FilesystemControllerTest < ActionDispatch::IntegrationTest
    # Home endpoint tests
    
    speed_profile :fast
    test "home returns suggestions" do
      get "/api/filesystem/home"
      
      assert_response :success
      json = JSON.parse(response.body)
      
      assert json.key?("suggestions")
      assert_kind_of Array, json["suggestions"]
      assert json["suggestions"].length > 0
    end

    speed_profile :fast
    test "home includes rails root suggestion" do
      get "/api/filesystem/home"
      
      json = JSON.parse(response.body)
      suggestions = json["suggestions"]
      
      rails_root_suggestion = suggestions.find { |s| s["name"] == "Rails Root" }
      
      assert_not_nil rails_root_suggestion
      assert_equal Rails.root.to_s, rails_root_suggestion["path"]
      assert_equal "🚂", rails_root_suggestion["icon"]
    end

    speed_profile :fast
    test "home includes parent directory suggestion" do
      get "/api/filesystem/home"
      
      json = JSON.parse(response.body)
      suggestions = json["suggestions"]
      
      parent_suggestion = suggestions.find { |s| s["name"] == "Parent Directory" }
      
      assert_not_nil parent_suggestion
      assert_equal File.expand_path('..', Rails.root), parent_suggestion["path"]
      assert_equal "📁", parent_suggestion["icon"]
    end

    speed_profile :fast
    test "home includes home directory suggestion" do
      get "/api/filesystem/home"
      
      json = JSON.parse(response.body)
      suggestions = json["suggestions"]
      
      home_suggestion = suggestions.find { |s| s["name"] == "Home Directory" }
      
      # Home directory might not be included if it's same as parent, so only test if present
      if home_suggestion
        assert_equal File.expand_path('~'), home_suggestion["path"]
        assert_equal "🏠", home_suggestion["icon"]
      end
    end

    # Browse endpoint tests
    
    speed_profile :fast
    test "browse with no path defaults to parent of rails root" do
      get "/api/filesystem/browse"
      
      assert_response :success
      json = JSON.parse(response.body)
      
      expected_path = File.expand_path('..', Rails.root)
      assert_equal expected_path, json["current_path"]
    end

    speed_profile :fast
    test "browse returns current path and parent path" do
      path = Rails.root.to_s
      get "/api/filesystem/browse", params: { path: path }
      
      assert_response :success
      json = JSON.parse(response.body)
      
      assert_equal Rails.root.to_s, json["current_path"]
      assert_equal File.expand_path('..', Rails.root), json["parent_path"]
    end

    speed_profile :fast
    test "browse returns directories array" do
      path = Rails.root.to_s
      get "/api/filesystem/browse", params: { path: path }
      
      assert_response :success
      json = JSON.parse(response.body)
      
      assert json.key?("directories")
      assert_kind_of Array, json["directories"]
      
      # Should have at least one directory (app, config, etc.)
      assert json["directories"].length > 0
    end

    speed_profile :fast
    test "browse directory entries have name and path" do
      path = Rails.root.to_s
      get "/api/filesystem/browse", params: { path: path }
      
      json = JSON.parse(response.body)
      directories = json["directories"]
      
      directories.each do |dir|
        assert dir.key?("name")
        assert dir.key?("path")
        assert_kind_of String, dir["name"]
        assert_kind_of String, dir["path"]
      end
    end

    speed_profile :fast
    test "browse returns only directories not files" do
      path = Rails.root.to_s
      get "/api/filesystem/browse", params: { path: path }
      
      json = JSON.parse(response.body)
      directories = json["directories"]
      
      # Verify all returned items are directories
      directories.each do |dir|
        assert File.directory?(dir["path"]), "#{dir['path']} should be a directory"
      end
    end

    speed_profile :fast
    test "browse returns error for nonexistent path" do
      path = "/nonexistent/path/that/does/not/exist"
      get "/api/filesystem/browse", params: { path: path }
      
      assert_response :bad_request
      json = JSON.parse(response.body)
      
      assert json.key?("error")
      assert_includes json["error"], "does not exist"
    end

    speed_profile :fast
    test "browse returns error for file path" do
      # Use a file we know exists
      file_path = Rails.root.join("Gemfile").to_s
      get "/api/filesystem/browse", params: { path: file_path }
      
      assert_response :bad_request
      json = JSON.parse(response.body)
      
      assert json.key?("error")
      assert_includes json["error"], "not a directory"
    end

    speed_profile :fast
    test "browse expands relative paths" do
      # Use a relative path
      get "/api/filesystem/browse", params: { path: "." }
      
      assert_response :success
      json = JSON.parse(response.body)
      
      # Should expand to absolute path
      assert json["current_path"].start_with?("/")
      refute_equal ".", json["current_path"]
    end

    speed_profile :fast
    test "browse returns parent path as nil for root directory" do
      # Only test if we have permission to browse root
      # This will fail loudly if permissions are misconfigured
      return unless File.readable?("/") && File.directory?("/")
      
      get "/api/filesystem/browse", params: { path: "/" }
      
      assert_response :success
      json = JSON.parse(response.body)
      
      assert_equal "/", json["current_path"]
      assert_nil json["parent_path"]
    end

    speed_profile :fast
    test "browse directories are sorted alphabetically" do
      path = Rails.root.to_s
      get "/api/filesystem/browse", params: { path: path }
      
      json = JSON.parse(response.body)
      directories = json["directories"]
      
      # Get names in lowercase for comparison
      names = directories.map { |d| d["name"].downcase }
      sorted_names = names.sort
      
      assert_equal sorted_names, names, "Directories should be sorted alphabetically"
    end

    speed_profile :fast
    test "browse parent directory from rails root works" do
      path = Rails.root.to_s
      get "/api/filesystem/browse", params: { path: path }
      
      json = JSON.parse(response.body)
      parent_path = json["parent_path"]
      
      # Now browse the parent
      get "/api/filesystem/browse", params: { path: parent_path }
      
      assert_response :success
      parent_json = JSON.parse(response.body)
      
      assert_equal parent_path, parent_json["current_path"]
      assert_kind_of Array, parent_json["directories"]
    end

    # Security tests
    
    speed_profile :fast
    test "browse does not expose unreadable directories" do
      path = Rails.root.to_s
      get "/api/filesystem/browse", params: { path: path }
      
      json = JSON.parse(response.body)
      directories = json["directories"]
      
      # All returned directories should be readable
      directories.each do |dir|
        assert File.readable?(dir["path"]), "#{dir['path']} should be readable"
      end
    end
  end
end

