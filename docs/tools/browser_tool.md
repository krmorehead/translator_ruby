# Browser Automation Tool

## Overview

The `BrowserTool` enables Sisyphus to automate browser interactions for web testing, scraping, and verification tasks. It uses headless Chrome/Chromium via the Ferrum gem to provide programmatic control over web pages.

**Privacy Note**: This tool is configured to use **DuckDuckGo** as the default search engine for privacy-focused browsing and searching.

## OOP Patterns Followed

This tool strictly adheres to the patterns defined in `docs/references/oop-patterns.md`:

1. **✅ Type Validation**: All inputs are validated for correct types (String, Integer, Boolean)
2. **✅ Fail-Fast**: Invalid inputs raise descriptive errors immediately
3. **✅ No Mocks**: Tests use real browser instances, never mocks
4. **✅ Immutable Configuration**: Configuration options are read-only
5. **✅ Descriptive Errors**: All errors include context about what went wrong
6. **✅ Result Objects**: Consistent result format with `:success`, `:data`, `:error`
7. **✅ Thread Safety**: Mutex-protected singleton browser instance

## Prerequisites

### System Requirements

1. **Chrome or Chromium browser** installed:
   ```bash
   # Ubuntu/Debian
   sudo apt-get install chromium-browser
   
   # macOS (via Homebrew)
   brew install --cask google-chrome
   
   # Or Chromium
   brew install --cask chromium
   ```

2. **Ferrum gem** (added to Gemfile):
   ```ruby
   gem "ferrum", "~> 0.15"
   ```

3. **Install dependencies**:
   ```bash
   bundle install
   ```

**Note**: While DuckDuckGo is the recommended search engine, the underlying browser automation uses Chrome/Chromium (the only reliably automatable browsers with full DevTools Protocol support).

## Features

The BrowserTool supports 9 core actions:

1. **launch** - Start a browser instance
2. **navigate** - Go to a URL
3. **click** - Click an element
4. **type** - Type text into an input
5. **screenshot** - Capture page screenshot
6. **get_content** - Extract page/element content
7. **evaluate_js** - Execute JavaScript
8. **wait_for** - Wait for element to appear
9. **close** - Close the browser

## Usage

### Tool Metadata

```ruby
Tools::Sisyphus::BrowserTool.metadata
# =>
# {
#   name: "browser",
#   description: "Automate browser interactions for web testing and automation",
#   parameters: {
#     type: "object",
#     properties: {
#       action: { type: "string", enum: ["launch", "navigate", ...] },
#       url: { type: "string" },
#       selector: { type: "string" },
#       text: { type: "string" },
#       script: { type: "string" },
#       timeout: { type: "integer", default: 30 },
#       screenshot_path: { type: "string" },
#       headless: { type: "boolean", default: true }
#     },
#     required: ["action"]
#   }
# }
```

### Action Reference

#### 1. Launch Browser

Start a browser instance.

**Parameters**:
- `action`: `"launch"` (required)
- `headless`: Boolean (optional, default: `true`)

**Example**:
```ruby
tool = Tools::Sisyphus::BrowserTool.new
result = tool.execute(action: "launch", headless: true)

# Result:
# {
#   success: true,
#   data: {
#     message: "Browser launched successfully",
#     headless: true,
#     browser_pid: 12345
#   },
#   tool: "browser",
#   timestamp: "2026-01-02T12:00:00Z"
# }
```

**LLM Usage**:
```json
{
  "name": "browser",
  "parameters": {
    "action": "launch",
    "headless": true
  }
}
```

#### 2. Navigate to URL

Navigate to a web page.

**Parameters**:
- `action`: `"navigate"` (required)
- `url`: String (required) - URL to navigate to

**Example**:
```ruby
result = tool.execute(
  action: "navigate",
  url: "https://example.com"
)

# Result:
# {
#   success: true,
#   data: {
#     message: "Navigated to https://example.com",
#     url: "https://example.com/",
#     title: "Example Domain"
#   }
# }
```

**LLM Usage**:
```json
{
  "name": "browser",
  "parameters": {
    "action": "navigate",
    "url": "https://example.com"
  }
}
```

#### 3. Click Element

Click a page element.

**Parameters**:
- `action`: `"click"` (required)
- `selector`: String (required) - CSS selector
- `timeout`: Integer (optional, default: 30) - Wait timeout in seconds

**Example**:
```ruby
result = tool.execute(
  action: "click",
  selector: "#submit-button",
  timeout: 10
)

# Result:
# {
#   success: true,
#   data: {
#     message: "Clicked element: #submit-button",
#     selector: "#submit-button"
#   }
# }
```

**LLM Usage**:
```json
{
  "name": "browser",
  "parameters": {
    "action": "click",
    "selector": "#submit-button"
  }
}
```

#### 4. Type Text

Type text into an input element.

**Parameters**:
- `action`: `"type"` (required)
- `selector`: String (required) - CSS selector for input
- `text`: String (required) - Text to type
- `timeout`: Integer (optional, default: 30)

**Example**:
```ruby
result = tool.execute(
  action: "type",
  selector: "#username",
  text: "john@example.com"
)

# Result:
# {
#   success: true,
#   data: {
#     message: "Typed 'john@example.com' into element: #username",
#     selector: "#username",
#     text: "john@example.com"
#   }
# }
```

**LLM Usage**:
```json
{
  "name": "browser",
  "parameters": {
    "action": "type",
    "selector": "#username",
    "text": "john@example.com"
  }
}
```

#### 5. Capture Screenshot

Take a screenshot of the page.

**Parameters**:
- `action`: `"screenshot"` (required)
- `screenshot_path`: String (optional) - File path (default: auto-generated)

**Example**:
```ruby
result = tool.execute(
  action: "screenshot",
  screenshot_path: "tmp/homepage.png"
)

# Result:
# {
#   success: true,
#   data: {
#     message: "Screenshot saved to tmp/homepage.png",
#     path: "/full/path/to/tmp/homepage.png",
#     size_bytes: 45678
#   }
# }
```

**LLM Usage**:
```json
{
  "name": "browser",
  "parameters": {
    "action": "screenshot",
    "screenshot_path": "tmp/test_result.png"
  }
}
```

#### 6. Get Content

Extract text content from page or element.

**Parameters**:
- `action`: `"get_content"` (required)
- `selector`: String (optional) - CSS selector (default: entire body)
- `timeout`: Integer (optional, default: 30)

**Example**:
```ruby
# Get entire page
result = tool.execute(action: "get_content")

# Get specific element
result = tool.execute(
  action: "get_content",
  selector: "#main-content"
)

# Result:
# {
#   success: true,
#   data: {
#     message: "Retrieved page content",
#     selector: "#main-content",
#     content: "Page content here...",
#     content_length: 1234
#   }
# }
```

**LLM Usage**:
```json
{
  "name": "browser",
  "parameters": {
    "action": "get_content",
    "selector": "#main-content"
  }
}
```

#### 7. Evaluate JavaScript

Execute JavaScript code in the page context.

**Parameters**:
- `action`: `"evaluate_js"` (required)
- `script`: String (required) - JavaScript code

**Example**:
```ruby
result = tool.execute(
  action: "evaluate_js",
  script: "document.title"
)

# Result:
# {
#   success: true,
#   data: {
#     message: "JavaScript executed successfully",
#     script: "document.title",
#     result: "Example Page Title"
#   }
# }
```

**LLM Usage**:
```json
{
  "name": "browser",
  "parameters": {
    "action": "evaluate_js",
    "script": "document.querySelectorAll('a').length"
  }
}
```

#### 8. Wait For Element

Wait for an element to appear.

**Parameters**:
- `action`: `"wait_for"` (required)
- `selector`: String (required) - CSS selector
- `timeout`: Integer (optional, default: 30)

**Example**:
```ruby
result = tool.execute(
  action: "wait_for",
  selector: "#loading-complete",
  timeout: 60
)

# Result:
# {
#   success: true,
#   data: {
#     message: "Element found: #loading-complete",
#     selector: "#loading-complete",
#     wait_duration_seconds: 2.34
#   }
# }
```

**LLM Usage**:
```json
{
  "name": "browser",
  "parameters": {
    "action": "wait_for",
    "selector": "#content-loaded",
    "timeout": 60
  }
}
```

#### 9. Close Browser

Close the browser instance.

**Parameters**:
- `action`: `"close"` (required)

**Example**:
```ruby
result = tool.execute(action: "close")

# Result:
# {
#   success: true,
#   data: {
#     message: "Browser closed successfully"
#   }
# }
```

**LLM Usage**:
```json
{
  "name": "browser",
  "parameters": {
    "action": "close"
  }
}
```

## Common Workflows

### Privacy-Focused Search with DuckDuckGo

```ruby
tool = Tools::Sisyphus::BrowserTool.new

# Launch browser
tool.execute(action: "launch")

# Search DuckDuckGo (no tracking, privacy-focused)
search_query = "Ruby programming best practices"
url = "https://duckduckgo.com/?q=#{URI.encode_www_form_component(search_query)}"

tool.execute(action: "navigate", url: url)

# Wait for results
tool.execute(action: "wait_for", selector: "#links", timeout: 10)

# Extract top 5 results
result = tool.execute(
  action: "evaluate_js",
  script: <<~JS
    Array.from(document.querySelectorAll('#links .result__title'))
      .slice(0, 5)
      .map(el => el.textContent.trim())
  JS
)

puts "Search Results:"
result[:data][:result].each_with_index do |title, i|
  puts "#{i + 1}. #{title}"
end

# Close browser
tool.execute(action: "close")
```

### Test a Login Flow

```ruby
tool = Tools::Sisyphus::BrowserTool.new

# Launch browser
tool.execute(action: "launch")

# Navigate to login page
tool.execute(action: "navigate", url: "https://app.example.com/login")

# Fill in username
tool.execute(action: "type", selector: "#username", text: "test@example.com")

# Fill in password
tool.execute(action: "type", selector: "#password", text: "test123")

# Click login button
tool.execute(action: "click", selector: "#login-button")

# Wait for dashboard to load
tool.execute(action: "wait_for", selector: "#dashboard", timeout: 10)

# Capture screenshot of logged-in state
tool.execute(action: "screenshot", screenshot_path: "tmp/logged_in.png")

# Verify success
result = tool.execute(action: "get_content", selector: "#welcome-message")
puts result[:data][:content] # => "Welcome, Test User!"

# Close browser
tool.execute(action: "close")
```

### Scrape Data from a Page

```ruby
tool = Tools::Sisyphus::BrowserTool.new

# Launch and navigate
tool.execute(action: "launch")
tool.execute(action: "navigate", url: "https://example.com/products")

# Wait for products to load
tool.execute(action: "wait_for", selector: ".product-card")

# Get product count
count_result = tool.execute(
  action: "evaluate_js",
  script: "document.querySelectorAll('.product-card').length"
)
puts "Found #{count_result[:data][:result]} products"

# Extract product names
names_result = tool.execute(
  action: "evaluate_js",
  script: "Array.from(document.querySelectorAll('.product-name')).map(el => el.textContent)"
)
product_names = names_result[:data][:result]

# Close browser
tool.execute(action: "close")
```

### Test Form Submission

```ruby
tool = Tools::Sisyphus::BrowserTool.new

tool.execute(action: "launch")
tool.execute(action: "navigate", url: "http://localhost:3000/contact")

# Fill form
tool.execute(action: "type", selector: "#name", text: "John Doe")
tool.execute(action: "type", selector: "#email", text: "john@example.com")
tool.execute(action: "type", selector: "#message", text: "Test message")

# Submit
tool.execute(action: "click", selector: "#submit")

# Wait for success message
tool.execute(action: "wait_for", selector: ".success-message", timeout: 10)

# Verify
result = tool.execute(action: "get_content", selector: ".success-message")
assert_includes result[:data][:content], "Thank you"

tool.execute(action: "close")
```

## Integration with Sisyphus

### Registering the Tool

The BrowserTool is automatically registered when the tools are loaded:

```ruby
# In app/services/tool_call_service.rb or similar
available_tools = [
  Tools::Sisyphus::WriteFileTool,
  Tools::Sisyphus::ReadFileTool,
  Tools::Sisyphus::BashTool,
  Tools::Sisyphus::BrowserTool  # <-- Add here
]
```

### LLM Prompt Integration

Add browser capabilities to the system prompt:

```ruby
# In app/prompts/execution/sisyphus_system_prompt.rb
capabilities = [
  "File operations (read, write)",
  "Command execution (bash)",
  "Browser automation (navigate, click, type, screenshot)"  # <-- Add
]

available_tools = [
  {
    name: "write_file",
    description: "Create or modify files"
  },
  {
    name: "bash",
    description: "Execute bash commands"
  },
  {
    name: "browser",  # <-- Add
    description: "Automate browser for testing web applications"
  }
]
```

### Example Plan with Browser Actions

```markdown
# Test User Registration

## Milestone 1: Setup Test Environment

### Step 1: Start Rails Server
**Intent**: Start the Rails development server

**Details**:
- Use bash tool to start Rails server in background
- Wait for server to be ready

**Tests**:
- Server responds on port 3000

### Step 2: Test Registration Flow
**Intent**: Verify user can register successfully

**Details**:
- Use browser tool to navigate to /signup
- Fill in registration form
- Submit form
- Verify success message appears
- Capture screenshot of confirmation

**Tests**:
- Success message displays: "Welcome! Your account has been created."
- Screenshot saved to tmp/registration_success.png
- User record exists in database
```

## Error Handling

### Element Not Found

```ruby
result = tool.execute(action: "click", selector: "#missing", timeout: 5)

# Result:
# {
#   success: false,
#   error: "Browser action failed: Element not found: #missing (timeout after 5s)",
#   tool: "browser",
#   timestamp: "2026-01-02T12:00:00Z"
# }
```

### Navigation Timeout

```ruby
result = tool.execute(action: "navigate", url: "https://slow-site.example.com")

# If page doesn't load within 60s (default browser timeout):
# {
#   success: false,
#   error: "Browser action failed: Navigation timeout",
#   error_class: "Ferrum::TimeoutError",
#   backtrace: [...]
# }
```

### JavaScript Errors

```ruby
result = tool.execute(action: "evaluate_js", script: "invalidJavaScript()")

# Result:
# {
#   success: false,
#   error: "Browser action failed: ReferenceError: invalidJavaScript is not defined",
#   error_class: "Ferrum::JavaScriptError",
#   backtrace: [...]
# }
```

## Testing

### Unit Tests

Run unit tests for the BrowserTool:

```bash
bundle exec ruby -Itest test/tools/sisyphus/browser_tool_test.rb
```

**Note**: Tests that require a browser will be skipped if Chrome/Chromium is not installed.

### Integration Tests

Create integration tests that use the browser tool:

```ruby
# test/integration/sisyphus_browser_test.rb
class SisyphusBrowserTest < ActionDispatch::IntegrationTest
  test "Sisyphus can test web application with browser tool" do
    # Start server in background
    # Create plan that uses browser tool
    # Execute plan
    # Verify browser actions completed successfully
  end
end
```

## Troubleshooting

### Chrome/Chromium Not Found

**Error**: `Chrome/Chromium not found in standard locations`

**Solution**: Install Chrome or Chromium:
```bash
# Ubuntu/Debian
sudo apt-get install chromium-browser

# macOS
brew install --cask google-chrome
```

### Ferrum Gem Not Found

**Error**: `Ferrum gem not found`

**Solution**: Add to Gemfile and install:
```bash
echo 'gem "ferrum", "~> 0.15"' >> Gemfile
bundle install
```

### Headless Mode Fails

**Error**: Browser crashes in headless mode

**Solution**: Try non-headless mode for debugging:
```ruby
tool.execute(action: "launch", headless: false)
```

Or add additional browser options:
```ruby
# In browser_tool.rb, modify create_browser:
browser_options: {
  "no-sandbox": nil,
  "disable-gpu": nil,
  "disable-dev-shm-usage": nil  # Add for limited /dev/shm
}
```

### Screenshots Are Blank

**Issue**: Screenshots save but are blank/white

**Possible Causes**:
1. Page hasn't fully loaded - add `wait_for` before screenshot
2. JavaScript hasn't rendered content - add delay or wait for element

**Solution**:
```ruby
# Wait for content to load
tool.execute(action: "wait_for", selector: "#main-content")

# Then take screenshot
tool.execute(action: "screenshot", screenshot_path: "tmp/page.png")
```

## Performance Considerations

### Browser Instance Reuse

The BrowserTool reuses a single browser instance across multiple actions:

```ruby
# First action launches browser
tool.execute(action: "launch")

# Subsequent actions reuse the same instance
tool.execute(action: "navigate", url: "https://example.com")
tool.execute(action: "screenshot")

# Explicitly close when done
tool.execute(action: "close")
```

### Memory Usage

Browser instances consume significant memory (100-300 MB). Always close the browser when done:

```ruby
begin
  tool.execute(action: "launch")
  # ... perform actions ...
ensure
  tool.execute(action: "close")
end
```

### Timeouts

Adjust timeouts for slow-loading pages:

```ruby
# Default 30s timeout
tool.execute(action: "wait_for", selector: "#content")

# Extended timeout for slow pages
tool.execute(action: "wait_for", selector: "#content", timeout: 120)
```

## Security Considerations

### Sanitize URLs

Always validate URLs before navigating:

```ruby
# Bad - user input directly to browser
tool.execute(action: "navigate", url: user_input)

# Good - validate URL first
url = URI.parse(user_input)
if url.scheme.in?(%w[http https]) && url.host.present?
  tool.execute(action: "navigate", url: url.to_s)
end
```

### Screenshot Paths

Validate screenshot paths to prevent directory traversal:

```ruby
# Bad - user controls path
tool.execute(action: "screenshot", screenshot_path: user_input)

# Good - constrain to safe directory
safe_path = Rails.root.join("tmp/screenshots", File.basename(user_input))
tool.execute(action: "screenshot", screenshot_path: safe_path.to_s)
```

### JavaScript Execution

Be cautious with `evaluate_js` - it runs with full page permissions:

```ruby
# Avoid executing untrusted scripts
tool.execute(action: "evaluate_js", script: untrusted_code)  # Dangerous!

# Only execute known, safe scripts
tool.execute(action: "evaluate_js", script: "document.title")  # Safe
```

## Related Documentation

- **Tool Base Class**: `app/tools/sisyphus/base_tool.rb`
- **Ferrum Documentation**: https://github.com/rubycdp/ferrum
- **Chrome DevTools Protocol**: https://chromedevtools.github.io/devtools-protocol/
- **Sisyphus Tools**: `docs/architecture/tool_system.md`
- **Integration Tests**: `test/integration/sisyphus_browser_test.rb`

