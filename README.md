# Translator Ruby

A Rails 8.0.2 API-only application built with Ruby 3.4.4 for translation services.

## ⚡ Quick Start

### Production Mode (Single Command)
```bash
bin/start-production
```
Builds frontend + starts Rails in production mode. Configure via `.env` file.

### Development Mode
```bash
# Backend (Rails API)
rvm use 3.4.4 && ruby lib/server.rb

# Frontend (React + Vite) - in separate terminal
cd frontend && npm run dev
```

### Testing
```bash
# Fast tests (~5 seconds)
ruby lib/test_runner.rb --speed fast

# All tests (~7 minutes)
ruby lib/test_runner.rb --speed all
```

---

## 🚀 Project Overview

This is a server-only Rails application designed to handle translation requests. The project is structured as an API-only application without frontend assets, but is designed to accommodate a frontend in the future.

## 🛠 Technology Stack

- **Ruby**: 3.4.4 (managed with RVM)
- **Rails**: 8.0.2
- **Database**: PostgreSQL 16
- **Testing**: TestUnit (Rails default) + FactoryBot
- **Environment**: dotenv-rails for configuration

## 📋 Prerequisites

- Ruby 3.4.4 (or compatible version)
- RVM (Ruby Version Manager)
- PostgreSQL
- Bundler

## 🔧 Setup Instructions

### 1. Ruby Environment Setup

```bash
# Install RVM if not already installed (using Homebrew)
brew install rvm

# Install and use Ruby 3.4.4
rvm install 3.4.4
rvm use 3.4.4
```

### 2. Project Setup

```bash
# Clone the repository
git clone <repository-url>
cd translator_ruby

# Install dependencies
bundle install

# Setup environment variables
cp env.example .env
# Edit .env with your configuration
```

### 3. Database Setup

```bash
# Ensure PostgreSQL is running
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create databases
rails db:create
rails db:migrate
```

### 4. Start the Server

#### Development Mode

```bash
# Using the custom server script (loads .env automatically, binds to 0.0.0.0:52020)
rvm use 3.4.4 && PORT=52020 ruby lib/server.rb

# Or using Rails directly with environment variables
rvm use 3.4.4 && rails server -p 52020 -b 0.0.0.0

# With explicit host and port environment variables
rvm use 3.4.4 && PORT=52020 HOST=0.0.0.0 ruby lib/server.rb
```

#### Production Mode

**Single command to build and start everything in production:**

```bash
bin/start-production
```

This production startup script will:
- ✅ Build the frontend (React + Vite)
- ✅ Install/verify dependencies
- ✅ Run database migrations
- ✅ Start Rails server in production mode on port 4000 (configurable via `.env`)

**Configuration**: Edit your `.env` file to set production values:
```bash
RAILS_ENV=production
PORT=4000
HOST=0.0.0.0
# ... other production settings
```

**Note**: The script reads configuration from `.env` file automatically.

## 🌐 API Endpoints

### Hello World Endpoint
- **URL**: `GET /api/v1/hello/index`
- **Response**: JSON with message, status, timestamp, and version
- **Example**:
  ```json
  {
    "message": "Hello World!",
    "status": "success", 
    "timestamp": "2025-08-05T03:01:44.591Z",
    "version": "1.0.0"
  }
  ```

## 🧪 Testing

The project uses Rails' default TestUnit framework with FactoryBot for advanced test data generation. Tests are organized with **per-test speed profiling** for efficient development iteration.

### Speed-Profiled Testing

The project uses a speed profiling system that categorizes tests by execution time:

- **Fast** (< 10 seconds): Unit tests, validations, pure logic
- **Medium** (< 60 seconds): Tests with LLM calls, tool execution, file I/O
- **Slow** (< 120 seconds): Workers, workflows, integration tests

### Running Tests

```bash
# Fast tests only (recommended for development) - runs in ~5 seconds
rvm use 3.4.4 && ruby lib/test_runner.rb --speed fast

# Fast + medium tests (for feature development) - runs in ~69 seconds
rvm use 3.4.4 && ruby lib/test_runner.rb --speed medium

# All tests (before PR/merge) - runs in ~7 minutes
rvm use 3.4.4 && ruby lib/test_runner.rb --speed all

# Run specific test file
rvm use 3.4.4 && ruby lib/test_runner.rb --speed fast test/controllers/api/v1/hello_controller_test.rb

# Run specific directory
rvm use 3.4.4 && ruby lib/test_runner.rb --speed fast test/models
```

### Writing Tests with Speed Profiles

**Every test MUST declare a speed profile before the test definition:**

```ruby
class MyTest < ActiveSupport::TestCase
  speed_profile :fast
  test "quick validation" do
    assert_equal 2, 1 + 1
  end
  
  speed_profile :medium
  test "with LLM call" do
    result = service.call_llm
    assert result.present?
  end
  
  speed_profile :fast
  test "another quick test" do
    assert true
  end
end
```

**Speed Profile Guidelines:**
- `:fast` - No external calls, pure logic, <10s
- `:medium` - LLM calls, file operations, <60s
- `:slow` - Complex workflows, integrations, <120s

Tests that exceed their SLA will be forcefully terminated and fail.

See [Test Speed Profiling Quick Reference](docs/test_speed_profiling_quick_reference.md) for more details.

### Test Structure

```
test/
├── test_helper.rb                           # Test configuration
├── fixtures/                                # Rails fixtures (YAML-based)
├── factories/                               # FactoryBot factories  
│   ├── hello_responses.rb                   # API response factories
│   └── users.rb                             # User factories (for future use)
├── controllers/api/v1/
│   └── hello_controller_test.rb             # Hello endpoint tests
└── factories_test.rb                        # FactoryBot factory tests
```

### Test Coverage

- **1214 comprehensive tests** across the entire codebase:
  - ~834 fast tests (<10s each)
  - ~175 medium tests (<60s each)
  - ~205 slow tests (<120s each)

Tests cover:
- Controllers and API endpoints
- Services and workflows
- Models and validations
- Prompts and LLM interactions
- Tools and utilities
- Workers and background jobs
- Integration scenarios

**Testing Philosophy:**
- No mocking or stubbing - real implementations only
- Per-test speed profiling for efficient iteration
- Comprehensive coverage with meaningful assertions
- Real data using FactoryBot
- Timeout enforcement at SLA boundaries

## 📁 Project Structure

```
translator_ruby/
├── app/
│   └── controllers/
│       ├── application_controller.rb       # Base API controller
│       └── api/v1/
│           └── hello_controller.rb         # Hello world endpoint
├── config/
│   ├── database.yml                        # PostgreSQL configuration
│   ├── routes.rb                           # API routes
│   └── environments/                       # Environment configs
├── lib/
│   ├── server.rb                           # Custom server startup script
│   └── test_runner.rb                      # Custom test runner script
├── test/                                   # Test suite (see above)
├── .env                                    # Environment variables (gitignored)
├── .gitignore                              # Git ignore rules
└── Gemfile                                 # Ruby dependencies
```

## ⚙️ Configuration

### Environment Variables (.env)

```bash
# Server Configuration
PORT=52020

# Database Configuration
DB_USERNAME=postgres
DB_PASSWORD=postgres
DB_HOST=localhost
DB_PORT=5432

# LLM Service Configuration  
LLM_URL=http://73.190.101.126:52003

# Rails Environment
RAILS_ENV=development
```

### Key Features

- **Environment Loading**: Custom server script automatically loads `.env`
- **Database Flexibility**: PostgreSQL with environment-based configuration
- **API Versioning**: Structured as `/api/v1/` for future version management
- **Testing**: Comprehensive test suite without mocking/stubbing
- **Development Tools**: Custom scripts for server and test execution

## 🚦 Development Workflow

### Testing Loop

1. **During development**: Run fast tests for rapid iteration
   ```bash
   ruby lib/test_runner.rb --speed fast  # ~5 seconds
   ```

2. **Testing new features**: Run fast + medium tests
   ```bash
   ruby lib/test_runner.rb --speed medium  # ~69 seconds
   ```

3. **Before PR/merge**: Run complete test suite
   ```bash
   ruby lib/test_runner.rb --speed all  # ~7 minutes
   ```

### Adding New Endpoints

1. Create controller in `app/controllers/api/v1/`
2. Add routes in `config/routes.rb`
3. Write comprehensive tests with speed profiles in `test/controllers/api/v1/`
4. Create factories if complex data structures needed
5. Run tests: `ruby lib/test_runner.rb --speed fast test/controllers/api/v1/your_controller_test.rb`

### Adding Models

1. Generate model: `rails generate model ModelName`
2. Create corresponding factory in `test/factories/`
3. Write model tests with speed profiles in `test/models/`
4. Update database with `rails db:migrate`
5. Run tests: `ruby lib/test_runner.rb --speed fast test/models/your_model_test.rb`

### Testing Philosophy

- **No Mocking**: Tests use real implementations and data
- **Comprehensive Coverage**: Each endpoint tested for multiple scenarios
- **Performance Aware**: Response time validation included
- **Security Focused**: HTTP method restrictions verified

## 🔒 Security Considerations

- API-only mode with CORS disabled by default
- No sensitive information exposed in API responses
- Environment variables for configuration (not committed to git)
- PostgreSQL with proper user authentication

## 🚀 Deployment

### Quick Production Startup

The easiest way to run in production mode:

```bash
bin/start-production
```

This single command handles:
- Frontend build (React + Vite)
- Dependency installation
- Database migrations
- Production server startup

### Production Requirements

- Ruby 3.4.4
- PostgreSQL
- Node.js (for frontend build)
- `.env` file with production configuration

### Advanced Deployment

- Uses Rails 8's solid components (Cache, Queue, Cable) - requires database
- Kamal deployment configuration included (`config/deploy.yml`)
- Docker support with Dockerfile
- PostgreSQL required in production

### Environment Variables for Production

Ensure your `.env` file has production values:
```bash
RAILS_ENV=production
PORT=4000
HOST=0.0.0.0
DB_USERNAME=your_prod_user
DB_PASSWORD=your_prod_password
LLM_URL=your_llm_service_url
```

## 📝 Contributing

1. Follow Rails conventions and project structure
2. Write comprehensive tests for all new features
3. **IMPORTANT**: Every test must declare `speed_profile :fast`, `:medium`, or `:slow`
4. Use FactoryBot for complex test data scenarios
5. Run `ruby lib/test_runner.rb --speed fast` during development
6. Run `ruby lib/test_runner.rb --speed all` before submitting PRs
7. Follow the existing code style and patterns
8. No mocking or stubbing - use real implementations

## 📚 Additional Resources

- [Rails 8.0 Release Notes](https://guides.rubyonrails.org/8_0_release_notes.html)
- [Rails API Documentation](https://api.rubyonrails.org/)
- [FactoryBot Documentation](https://thoughtbot.github.io/factory_bot/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Test Speed Profiling Guide](docs/test_speed_profiling_quick_reference.md)
- [Test Speed Profiling Verification](docs/test_speed_profiling_verification.md)

---

**Current Status**: ✅ Production-ready with comprehensive test suite and speed profiling system
