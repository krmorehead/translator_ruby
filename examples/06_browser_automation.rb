#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Browser Automation with DuckDuckGo
#
# This example demonstrates using the BrowserTool to:
# - Launch a browser instance
# - Search DuckDuckGo (privacy-focused search)
# - Extract search results
# - Capture screenshots
# - Navigate and interact with pages
#
# Prerequisites:
# - Chrome/Chromium installed
# - Ferrum gem installed (bundle install)
# - Internet connection

require_relative "../config/environment"

puts "=" * 80
puts "Browser Automation Example - DuckDuckGo Search"
puts "=" * 80
puts

# Initialize the browser tool
tool = Tools::Sisyphus::BrowserTool.new

begin
  # Step 1: Launch browser
  puts "Step 1: Launching browser..."
  result = tool.execute(action: "launch", headless: true)
  
  if result[:success]
    puts "✓ Browser launched"
    puts "  PID: #{result[:data][:browser_pid]}"
    puts "  Headless: #{result[:data][:headless]}"
  else
    puts "❌ Failed to launch browser: #{result[:error]}"
    exit 1
  end
  
  puts
  
  # Step 2: Search DuckDuckGo
  puts "Step 2: Searching DuckDuckGo..."
  search_query = "Ruby programming language"
  
  result = tool.execute(
    action: "navigate",
    url: "https://duckduckgo.com/?q=#{URI.encode_www_form_component(search_query)}"
  )
  
  if result[:success]
    puts "✓ Navigated to search results"
    puts "  URL: #{result[:data][:url]}"
    puts "  Title: #{result[:data][:title]}"
  else
    puts "❌ Failed to navigate: #{result[:error]}"
  end
  
  puts
  
  # Step 3: Wait for results to load
  puts "Step 3: Waiting for results..."
  result = tool.execute(
    action: "wait_for",
    selector: "#links",
    timeout: 10
  )
  
  if result[:success]
    puts "✓ Results loaded"
    puts "  Wait duration: #{result[:data][:wait_duration_seconds]}s"
  else
    puts "❌ Results didn't load: #{result[:error]}"
  end
  
  puts
  
  # Step 4: Extract search results
  puts "Step 4: Extracting search results..."
  result = tool.execute(
    action: "evaluate_js",
    script: <<~JS
      Array.from(document.querySelectorAll('#links .result__title')).slice(0, 5).map(el => el.textContent.trim())
    JS
  )
  
  if result[:success] && result[:data][:result]
    puts "✓ Found #{result[:data][:result].length} results:"
    result[:data][:result].each_with_index do |title, index|
      puts "  #{index + 1}. #{title}"
    end
  else
    puts "⚠️  Could not extract results"
  end
  
  puts
  
  # Step 5: Capture screenshot
  puts "Step 5: Capturing screenshot..."
  screenshot_path = "tmp/duckduckgo_search.png"
  FileUtils.mkdir_p("tmp")
  
  result = tool.execute(
    action: "screenshot",
    screenshot_path: screenshot_path
  )
  
  if result[:success]
    puts "✓ Screenshot saved"
    puts "  Path: #{result[:data][:path]}"
    puts "  Size: #{(result[:data][:size_bytes] / 1024.0).round(1)} KB"
  else
    puts "❌ Failed to capture screenshot: #{result[:error]}"
  end
  
  puts
  
  # Step 6: Navigate to Ruby homepage
  puts "Step 6: Navigating to Ruby homepage..."
  result = tool.execute(
    action: "navigate",
    url: "https://www.ruby-lang.org"
  )
  
  if result[:success]
    puts "✓ Navigated to Ruby homepage"
    puts "  Title: #{result[:data][:title]}"
  else
    puts "❌ Failed to navigate: #{result[:error]}"
  end
  
  puts
  
  # Step 7: Get page content
  puts "Step 7: Extracting page content..."
  result = tool.execute(
    action: "get_content",
    selector: "h1"
  )
  
  if result[:success]
    puts "✓ Page headline: #{result[:data][:content]}"
  else
    puts "⚠️  Could not extract content"
  end
  
  puts
  
  # Step 8: Test form interaction
  puts "Step 8: Testing form interaction (DuckDuckGo search box)..."
  result = tool.execute(
    action: "navigate",
    url: "https://duckduckgo.com"
  )
  
  if result[:success]
    # Type into search box
    result = tool.execute(
      action: "type",
      selector: "#searchbox_input",
      text: "Sisyphus automation"
    )
    
    if result[:success]
      puts "✓ Typed into search box"
      
      # Click search button
      result = tool.execute(
        action: "click",
        selector: "button[type='submit']"
      )
      
      if result[:success]
        puts "✓ Clicked search button"
        
        # Wait for new results
        result = tool.execute(
          action: "wait_for",
          selector: "#links",
          timeout: 10
        )
        
        if result[:success]
          puts "✓ Search completed"
        end
      end
    end
  end
  
  puts
  puts "=" * 80
  puts "Browser Automation Example Complete!"
  puts "=" * 80
  puts
  puts "Summary:"
  puts "- Browser launched successfully"
  puts "- Searched DuckDuckGo (privacy-focused)"
  puts "- Extracted search results"
  puts "- Captured screenshots"
  puts "- Navigated multiple pages"
  puts "- Interacted with form elements"
  puts
  puts "Screenshot saved to: #{screenshot_path}"
  puts
  
ensure
  # Always close browser
  puts "Closing browser..."
  tool.execute(action: "close")
  puts "✓ Browser closed"
end

puts "=" * 80
puts "Additional Examples:"
puts "=" * 80
puts
puts "1. Test a local web application:"
puts "   tool.execute(action: 'navigate', url: 'http://localhost:3000')"
puts
puts "2. Test authentication:"
puts "   tool.execute(action: 'type', selector: '#email', text: 'user@example.com')"
puts "   tool.execute(action: 'type', selector: '#password', text: 'password')"
puts "   tool.execute(action: 'click', selector: '#login-button')"
puts
puts "3. Scrape data:"
puts "   script = 'Array.from(document.querySelectorAll(\".product\")).map(p => p.textContent)'"
puts "   tool.execute(action: 'evaluate_js', script: script)"
puts
puts "4. Privacy-focused browsing:"
puts "   # Use DuckDuckGo for all searches (no tracking)"
puts "   tool.execute(action: 'navigate', url: 'https://duckduckgo.com/?q=your+query')"
puts
puts "For more information, see: docs/tools/browser_tool.md"
puts








