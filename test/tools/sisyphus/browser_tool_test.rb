# frozen_string_literal: true

require "test_helper"

class BrowserToolTest < ActiveSupport::TestCase
  def setup
    @tool = Sisyphus::BrowserTool.new
  end

  def teardown
    cleanup_browser
  end

  # Metadata tests
  speed_profile :fast
  test "metadata includes correct tool name" do
    metadata = Sisyphus::BrowserTool.metadata
    assert_equal "browser", metadata[:name]
  end

  speed_profile :fast
  test "metadata includes all actions" do
    metadata = Sisyphus::BrowserTool.metadata
    actions = metadata[:parameters][:properties][:action][:enum]
    
    expected_actions = %w[launch navigate click type screenshot get_content evaluate_js wait_for close]
    assert_equal expected_actions.sort, actions.sort
  end

  speed_profile :fast
  test "metadata includes required parameters" do
    metadata = Sisyphus::BrowserTool.metadata
    required = metadata[:parameters][:required]
    
    assert_includes required, "action"
  end

  # Parameter validation tests
  speed_profile :fast
  test "execute raises error when params is not a hash" do
    error = assert_raises(ArgumentError) do
      @tool.execute("not a hash")
    end
    assert_match(/must be a Hash/, error.message)
  end

  speed_profile :fast
  test "execute raises error when action is missing" do
    error = assert_raises(ArgumentError) do
      @tool.execute({})
    end
    assert_match(/Action parameter is required/, error.message)
  end

  speed_profile :fast
  test "execute returns error for invalid action" do
    result = @tool.execute(action: "invalid_action")
    
    refute result[:success]
    assert_match(/Invalid action/, result[:error])
  end

  # Launch action tests
  speed_profile :medium
  test "launch action creates browser instance" do
    skip_if_no_browser
    
    result = @tool.execute(action: "launch", headless: true)
    
    assert result[:success]
    assert_equal "Browser launched successfully", result[:data][:message]
    assert result[:data][:headless]
  end

  speed_profile :medium
  test "launch action works in non-headless mode" do
    skip_if_no_browser
    skip "Non-headless mode requires display" if ENV["CI"]
    
    result = @tool.execute(action: "launch", headless: false)
    
    assert result[:success]
    refute result[:data][:headless]
  end

  # Navigate action tests
  speed_profile :medium
  test "navigate action requires URL parameter" do
    skip_if_no_browser
    
    @tool.execute(action: "launch")
    result = @tool.execute(action: "navigate")
    
    refute result[:success]
    assert_match(/URL is required/, result[:error])
  end

  speed_profile :medium
  test "navigate action navigates to URL" do
    skip_if_no_browser
    skip "Requires test server" unless test_server_running?
    
    @tool.execute(action: "launch")
    result = @tool.execute(action: "navigate", url: "http://localhost:#{test_server_port}")
    
    assert result[:success]
    assert_match(/Navigated to/, result[:data][:message])
    assert_includes result[:data][:url], "localhost"
  end

  # Click action tests
  speed_profile :medium
  test "click action requires selector parameter" do
    skip_if_no_browser
    
    @tool.execute(action: "launch")
    result = @tool.execute(action: "click")
    
    refute result[:success]
    assert_match(/Selector is required/, result[:error])
  end

  speed_profile :medium
  test "click action returns error for non-existent element" do
    skip_if_no_browser
    skip "Requires test server" unless test_server_running?
    
    @tool.execute(action: "launch")
    @tool.execute(action: "navigate", url: "http://localhost:#{test_server_port}")
    
    result = @tool.execute(action: "click", selector: "#nonexistent", timeout: 2)
    
    refute result[:success]
    assert_match(/Element not found/, result[:error])
  end

  # Type action tests
  speed_profile :medium
  test "type action requires selector and text parameters" do
    skip_if_no_browser
    
    @tool.execute(action: "launch")
    
    # Missing text
    result = @tool.execute(action: "type", selector: "#input")
    refute result[:success]
    assert_match(/Text is required/, result[:error])
    
    # Missing selector
    result = @tool.execute(action: "type", text: "hello")
    refute result[:success]
    assert_match(/Selector is required/, result[:error])
  end

  # Screenshot action tests
  speed_profile :medium
  test "screenshot action captures page screenshot" do
    skip_if_no_browser
    skip "Requires test server" unless test_server_running?
    
    screenshot_path = Rails.root.join("tmp/test_screenshot.png").to_s
    FileUtils.rm_f(screenshot_path)
    
    @tool.execute(action: "launch")
    @tool.execute(action: "navigate", url: "http://localhost:#{test_server_port}")
    result = @tool.execute(action: "screenshot", screenshot_path: screenshot_path)
    
    assert result[:success]
    assert_match(/Screenshot saved/, result[:data][:message])
    assert File.exist?(screenshot_path)
    assert result[:data][:size_bytes] > 0
  ensure
    FileUtils.rm_f(screenshot_path) if screenshot_path
  end

  speed_profile :medium
  test "screenshot action uses default filename when path not provided" do
    skip_if_no_browser
    skip "Requires test server" unless test_server_running?
    
    @tool.execute(action: "launch")
    @tool.execute(action: "navigate", url: "http://localhost:#{test_server_port}")
    result = @tool.execute(action: "screenshot")
    
    assert result[:success]
    screenshot_path = result[:data][:path]
    assert File.exist?(screenshot_path)
  ensure
    FileUtils.rm_f(screenshot_path) if screenshot_path && File.exist?(screenshot_path)
  end

  # Get content action tests
  speed_profile :medium
  test "get_content action returns page body" do
    skip_if_no_browser
    skip "Requires test server" unless test_server_running?
    
    @tool.execute(action: "launch")
    @tool.execute(action: "navigate", url: "http://localhost:#{test_server_port}")
    result = @tool.execute(action: "get_content")
    
    assert result[:success]
    assert result[:data][:content].present?
    assert result[:data][:content_length] > 0
  end

  speed_profile :medium
  test "get_content action can get element content" do
    skip_if_no_browser
    skip "Requires test server" unless test_server_running?
    
    @tool.execute(action: "launch")
    @tool.execute(action: "navigate", url: "http://localhost:#{test_server_port}")
    result = @tool.execute(action: "get_content", selector: "h1")
    
    assert result[:success]
    assert result[:data][:content].present?
  end

  # Evaluate JS action tests
  speed_profile :medium
  test "evaluate_js action requires script parameter" do
    skip_if_no_browser
    
    @tool.execute(action: "launch")
    result = @tool.execute(action: "evaluate_js")
    
    refute result[:success]
    assert_match(/Script is required/, result[:error])
  end

  speed_profile :medium
  test "evaluate_js action executes JavaScript" do
    skip_if_no_browser
    skip "Requires test server" unless test_server_running?
    
    @tool.execute(action: "launch")
    @tool.execute(action: "navigate", url: "http://localhost:#{test_server_port}")
    result = @tool.execute(action: "evaluate_js", script: "2 + 2")
    
    assert result[:success]
    assert_equal 4, result[:data][:result]
  end

  # Wait for action tests
  speed_profile :medium
  test "wait_for action requires selector parameter" do
    skip_if_no_browser
    
    @tool.execute(action: "launch")
    result = @tool.execute(action: "wait_for")
    
    refute result[:success]
    assert_match(/Selector is required/, result[:error])
  end

  speed_profile :medium
  test "wait_for action waits for element" do
    skip_if_no_browser
    skip "Requires test server" unless test_server_running?
    
    @tool.execute(action: "launch")
    @tool.execute(action: "navigate", url: "http://localhost:#{test_server_port}")
    result = @tool.execute(action: "wait_for", selector: "body", timeout: 5)
    
    assert result[:success]
    assert_includes result[:data][:message], "Element found"
    assert result[:data][:wait_duration_seconds] >= 0
  end

  speed_profile :medium
  test "wait_for action times out for non-existent element" do
    skip_if_no_browser
    skip "Requires test server" unless test_server_running?
    
    @tool.execute(action: "launch")
    @tool.execute(action: "navigate", url: "http://localhost:#{test_server_port}")
    result = @tool.execute(action: "wait_for", selector: "#never-exists", timeout: 2)
    
    refute result[:success]
    assert_match(/Element not found/, result[:error])
    assert_match(/timeout/, result[:error])
  end

  # Close action tests
  speed_profile :medium
  test "close action closes browser instance" do
    skip_if_no_browser
    
    @tool.execute(action: "launch")
    result = @tool.execute(action: "close")
    
    assert result[:success]
    assert_equal "Browser closed successfully", result[:data][:message]
  end

  speed_profile :medium
  test "close action handles already closed browser gracefully" do
    skip_if_no_browser
    
    result = @tool.execute(action: "close")
    
    assert result[:success]
    assert_equal "Browser was not running", result[:data][:message]
  end

  # Integration tests
  speed_profile :medium
  test "browser can handle multiple actions in sequence" do
    skip_if_no_browser
    skip "Requires test server" unless test_server_running?
    
    # Launch
    result = @tool.execute(action: "launch")
    assert result[:success]
    
    # Navigate
    result = @tool.execute(action: "navigate", url: "http://localhost:#{test_server_port}")
    assert result[:success]
    
    # Get content
    result = @tool.execute(action: "get_content")
    assert result[:success]
    
    # Screenshot
    screenshot_path = Rails.root.join("tmp/sequence_test.png").to_s
    result = @tool.execute(action: "screenshot", screenshot_path: screenshot_path)
    assert result[:success]
    
    # Close
    result = @tool.execute(action: "close")
    assert result[:success]
  ensure
    FileUtils.rm_f(screenshot_path) if screenshot_path
  end

  private

  def cleanup_browser
    # Use class method for cleanup - encapsulates cleanup logic
    Sisyphus::BrowserTool.cleanup
  end

  def skip_if_no_browser
    # Check if Chrome/Chromium is available
    chrome_paths = %w[
      /usr/bin/google-chrome
      /usr/bin/chromium-browser
      /usr/bin/chromium
      /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome
    ]
    
    unless chrome_paths.any? { |path| File.exist?(path) }
      skip "Chrome/Chromium not found. Install Chrome to run browser tests."
    end
  end

  def test_server_running?
    # Check if test server is running on port 3001
    require "socket"
    TCPSocket.new("localhost", test_server_port).close
    true
  rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
    false
  end

  def test_server_port
    ENV.fetch("TEST_SERVER_PORT", "3001").to_i
  end
end








