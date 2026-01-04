# frozen_string_literal: true

module Sisyphus
  # BrowserTool - Automate browser interactions for web testing and scraping
    #
    # This tool enables Sisyphus to:
    # - Launch and control browser instances (Chrome/Chromium)
    # - Navigate to URLs (including DuckDuckGo for privacy-focused searches)
    # - Interact with page elements (click, type, select)
    # - Capture screenshots
    # - Extract page content
    # - Execute JavaScript
    # - Wait for elements and conditions
    #
    # OOP Patterns Followed:
    # - Type validation on all inputs (fail-fast)
    # - No mocks - uses real browser instances
    # - Immutable configuration
    # - Proper error handling with descriptive messages
    # - Result objects instead of mixed return types
    #
    # Uses headless Chrome/Chromium via Ferrum gem
    # Note: While DuckDuckGo is used for searches, the underlying browser
    # is Chrome/Chromium (the only reliably automatable browsers)
    #
    # Example usage in LLM prompts:
    #   {
    #     "name": "browser",
    #     "parameters": {
    #       "action": "navigate",
    #       "url": "https://duckduckgo.com"
    #     }
    #   }
    #
    class BrowserTool < BaseTool
      # Available browser actions
      ACTIONS = %i[
        launch
        navigate
        click
        type
        screenshot
        get_content
        evaluate_js
        wait_for
        close
      ].freeze

      # Default homepage for new browser instances
      DEFAULT_HOMEPAGE = "https://duckduckgo.com"

      # Browser instance (singleton per execution)
      # Note: Using class variables for singleton pattern per OOP patterns
      @browser = nil
      @browser_mutex = Mutex.new

      class << self
        attr_reader :browser, :browser_mutex
      end

      def initialize
        super
        validate_dependencies!
      end

      # Tool metadata for LLM
      def self.metadata
        {
          name: "browser",
          description: "Automate browser interactions for web testing and automation",
          parameters: {
            type: "object",
            properties: {
              action: {
                type: "string",
                enum: ACTIONS.map(&:to_s),
                description: "The browser action to perform"
              },
              url: {
                type: "string",
                description: "URL to navigate to (for navigate action)"
              },
              selector: {
                type: "string",
                description: "CSS selector for element interactions (for click, type, wait_for)"
              },
              text: {
                type: "string",
                description: "Text to type into an input (for type action)"
              },
              script: {
                type: "string",
                description: "JavaScript code to execute (for evaluate_js action)"
              },
              timeout: {
                type: "integer",
                description: "Timeout in seconds (for wait_for action)",
                default: 30
              },
              screenshot_path: {
                type: "string",
                description: "File path to save screenshot (for screenshot action)"
              },
              headless: {
                type: "boolean",
                description: "Run browser in headless mode",
                default: true
              }
            },
            required: ["action"]
          }
        }
      end

      # Execute the browser action
      #
      # OOP Pattern: Type validation, fail-fast errors, descriptive messages
      #
      # @param params [Hash] Tool parameters
      # @option params [String] :action The action to perform (required)
      # @option params [String] :url URL to navigate to (for navigate)
      # @option params [String] :selector CSS selector for element
      # @option params [String] :text Text to type
      # @option params [String] :script JavaScript to execute
      # @option params [Integer] :timeout Timeout in seconds (default: 30)
      # @option params [String] :screenshot_path Path to save screenshot
      # @option params [Boolean] :headless Run headless (default: true)
      #
      # @return [Hash] Result with success status and data
      # @raise [ArgumentError] if params invalid
      # @raise [TypeError] if param types incorrect
      def execute(params)
        # OOP Pattern: Fail-fast validation with descriptive errors
        validate_params!(params)
        validate_action!(params[:action])

        action = params[:action].to_sym

        begin
          # OOP Pattern: Use real browser instances, no mocks
          result = send("action_#{action}", params)
          success_result(result)
        rescue StandardError => e
          # OOP Pattern: Descriptive error messages
          error_result("Browser action '#{action}' failed: #{e.message}", error: e)
        end
      end

      private

      # Launch browser instance
      #
      # OOP Pattern: Type validation on inputs
      def action_launch(params)
        headless = params.fetch(:headless, true)
        
        # OOP Pattern: Type validation
        unless [true, false].include?(headless)
          raise TypeError, "headless must be a Boolean, got #{headless.class}"
        end
        
        # OOP Pattern: Thread-safe singleton creation
        self.class.browser_mutex.synchronize do
          self.class.instance_variable_set(:@browser, create_browser(headless: headless))
        end
        
        {
          message: "Browser launched successfully (Chrome/Chromium)",
          headless: headless,
          browser_pid: browser_pid,
          default_homepage: DEFAULT_HOMEPAGE
        }
      end

      # Navigate to URL
      #
      # OOP Pattern: Type validation and fail-fast
      def action_navigate(params)
        url = params[:url]
        
        # OOP Pattern: Fail-fast validation with descriptive errors
        unless url.is_a?(String) && !url.empty?
          raise ArgumentError, "URL must be a non-empty String, got #{url.inspect}"
        end
        
        # OOP Pattern: Validate URL format
        begin
          uri = URI.parse(url)
          unless uri.scheme.in?(%w[http https])
            raise ArgumentError, "URL must use http or https scheme, got #{uri.scheme}"
          end
        rescue URI::InvalidURIError => e
          raise ArgumentError, "Invalid URL format: #{e.message}"
        end

        browser.goto(url)
        
        {
          message: "Navigated to #{url}",
          url: browser.current_url,
          title: browser.title,
          loaded_at: Time.now.utc.iso8601
        }
      end

      # Click an element
      #
      # OOP Pattern: Type validation on all inputs
      def action_click(params)
        selector = params[:selector]
        timeout = params.fetch(:timeout, 30)
        
        # OOP Pattern: Fail-fast validation
        unless selector.is_a?(String) && !selector.empty?
          raise ArgumentError, "Selector must be a non-empty String, got #{selector.inspect}"
        end
        
        unless timeout.is_a?(Integer) && timeout > 0
          raise TypeError, "Timeout must be a positive Integer, got #{timeout.inspect}"
        end

        element = find_element(selector, timeout)
        element.click
        
        {
          message: "Clicked element: #{selector}",
          selector: selector,
          clicked_at: Time.now.utc.iso8601
        }
      end

      # Type text into an element
      #
      # OOP Pattern: Type validation on all inputs
      def action_type(params)
        selector = params[:selector]
        text = params[:text]
        timeout = params.fetch(:timeout, 30)
        
        # OOP Pattern: Fail-fast validation with descriptive errors
        unless selector.is_a?(String) && !selector.empty?
          raise ArgumentError, "Selector must be a non-empty String, got #{selector.inspect}"
        end
        
        unless text.is_a?(String)
          raise TypeError, "Text must be a String, got #{text.class}"
        end
        
        unless timeout.is_a?(Integer) && timeout > 0
          raise TypeError, "Timeout must be a positive Integer, got #{timeout.inspect}"
        end

        element = find_element(selector, timeout)
        element.focus
        element.type(text)
        
        {
          message: "Typed text into element: #{selector}",
          selector: selector,
          text_length: text.length,
          typed_at: Time.now.utc.iso8601
        }
      end

      # Capture screenshot
      def action_screenshot(params)
        path = params[:screenshot_path] || "screenshot_#{Time.now.to_i}.png"
        
        # Ensure directory exists
        FileUtils.mkdir_p(File.dirname(path)) if File.dirname(path) != "."
        
        browser.screenshot(path: path, full: true)
        
        {
          message: "Screenshot saved to #{path}",
          path: File.expand_path(path),
          size_bytes: File.size(path)
        }
      end

      # Get page content
      def action_get_content(params)
        selector = params[:selector]
        
        content = if selector
          element = find_element(selector, params[:timeout] || 30)
          element.inner_text
        else
          browser.body
        end
        
        {
          message: "Retrieved page content",
          selector: selector || "body",
          content: content,
          content_length: content.length
        }
      end

      # Evaluate JavaScript
      def action_evaluate_js(params)
        script = params[:script]
        raise ArgumentError, "Script is required for evaluate_js action" unless script

        result = browser.evaluate(script)
        
        {
          message: "JavaScript executed successfully",
          script: script,
          result: result
        }
      end

      # Wait for element or condition
      def action_wait_for(params)
        selector = params[:selector]
        timeout = params[:timeout] || 30
        
        raise ArgumentError, "Selector is required for wait_for action" unless selector

        start_time = Time.now
        element = find_element(selector, timeout)
        wait_duration = Time.now - start_time
        
        {
          message: "Element found: #{selector}",
          selector: selector,
          wait_duration_seconds: wait_duration.round(2)
        }
      end

      # Close browser instance
      def action_close(_params)
        if self.class.browser
          self.class.browser.quit
          self.class.instance_variable_set(:@browser, nil)
          
          {
            message: "Browser closed successfully"
          }
        else
          {
            message: "Browser was not running"
          }
        end
      end
      
      # Helper: Search DuckDuckGo (privacy-focused search)
      #
      # This is a convenience method for using DuckDuckGo search
      # Can be called as a standalone action or used internally
      #
      # @param query [String] Search query
      # @return [Hash] Search results page info
      def search_duckduckgo(query)
        unless query.is_a?(String) && !query.empty?
          raise ArgumentError, "Query must be a non-empty String"
        end
        
        # Navigate to DuckDuckGo search
        search_url = "https://duckduckgo.com/?q=#{URI.encode_www_form_component(query)}"
        browser.goto(search_url)
        
        # Wait for results to load
        find_element("#links", 10)
        
        {
          message: "Searched DuckDuckGo for: #{query}",
          query: query,
          url: browser.current_url,
          title: browser.title
        }
      end

      # Get or create browser instance
      def browser
        self.class.browser_mutex.synchronize do
          self.class.browser || begin
            self.class.instance_variable_set(:@browser, create_browser)
          end
        end
      end

      # Create new browser instance
      def create_browser(headless: true)
        require "ferrum"
        
        Ferrum::Browser.new(
          headless: headless,
          timeout: 60,
          window_size: [1280, 1024],
          browser_options: {
            "no-sandbox": nil,
            "disable-gpu": nil
          }
        )
      rescue LoadError
        raise ToolError, "Ferrum gem not found. Add 'gem \"ferrum\"' to Gemfile and run 'bundle install'"
      end

      # Find element with timeout
      def find_element(selector, timeout)
        deadline = Time.now + timeout
        
        loop do
          element = browser.at_css(selector)
          return element if element
          
          if Time.now > deadline
            raise ToolError, "Element not found: #{selector} (timeout after #{timeout}s)"
          end
          
          sleep 0.5
        end
      end

      # Get browser process ID
      def browser_pid
        self.class.browser&.process&.pid
      rescue StandardError
        nil
      end

      # Validate required dependencies
      def validate_dependencies!
        # Check if Chrome/Chromium is available
        chrome_paths = %w[
          /usr/bin/google-chrome
          /usr/bin/chromium-browser
          /usr/bin/chromium
          /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome
        ]
        
        unless chrome_paths.any? { |path| File.exist?(path) }
          Rails.logger.warn("Chrome/Chromium not found in standard locations. Browser tool may not work.")
        end
      end

      # Validate action parameters
      #
      # OOP Pattern: Fail-fast with descriptive error messages
      def validate_params!(params)
        unless params.is_a?(Hash)
          raise TypeError, "Parameters must be a Hash, got #{params.class}"
        end

        unless params.key?(:action)
          raise ArgumentError, "Action parameter is required"
        end
        
        unless params[:action].is_a?(String) || params[:action].is_a?(Symbol)
          raise TypeError, "Action must be a String or Symbol, got #{params[:action].class}"
        end
      end
      
      # Validate action is supported
      #
      # OOP Pattern: Fail-fast validation
      def validate_action!(action)
        action_sym = action.to_sym
        
        unless ACTIONS.include?(action_sym)
          raise ArgumentError, "Invalid action '#{action}'. Must be one of: #{ACTIONS.join(', ')}"
        end
      end

      # Format success result
      def success_result(data)
        {
          success: true,
          data: data,
          tool: "browser",
          timestamp: Time.now.utc.iso8601
        }
      end

      # Format error result
      def error_result(message, error: nil)
        result = {
          success: false,
          error: message,
          tool: "browser",
          timestamp: Time.now.utc.iso8601
        }
        
        if error
          result[:error_class] = error.class.name
          result[:backtrace] = error.backtrace.first(5)
        end
        
        result
      end

      # Custom error class for browser tool errors
      class ToolError < StandardError; end
    end
  end

