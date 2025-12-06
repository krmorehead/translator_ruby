# Translator Ruby

A Rails 8.0.2 API-only application built with Ruby 3.4.4 for translation services.

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

```bash
# Using the custom server script (loads .env automatically, binds to 0.0.0.0:52020)
rvm use 3.4.4 && PORT=52020 ruby lib/server.rb

# Or using Rails directly with environment variables
rvm use 3.4.4 && rails server -p 52020 -b 0.0.0.0

# With explicit host and port environment variables
rvm use 3.4.4 && PORT=52020 HOST=0.0.0.0 ruby lib/server.rb
```

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

The project uses Rails' default TestUnit framework with FactoryBot for advanced test data generation.

### Running Tests

```bash
# Run all tests using custom test runner (loads .env)
rvm use 3.4.4 && ruby lib/test_runner.rb

# Run specific test files
rvm use 3.4.4 && ruby lib/test_runner.rb test/controllers/api/v1/hello_controller_test.rb

# Run tests with explicit environment variables
rvm use 3.4.4 && DB_USERNAME=postgres DB_PASSWORD=postgres rails test
```

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

- **16 comprehensive controller tests** covering:
  - HTTP response validation
  - JSON structure verification
  - Timestamp format validation
  - Error handling
  - Performance testing
  - Security (HTTP method restrictions)

- **3 factory tests** covering:
  - Data generation validation
  - Format compliance
  - Uniqueness verification

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

### Adding New Endpoints

1. Create controller in `app/controllers/api/v1/`
2. Add routes in `config/routes.rb`
3. Write comprehensive tests in `test/controllers/api/v1/`
4. Create factories if complex data structures needed

### Adding Models

1. Generate model: `rails generate model ModelName`
2. Create corresponding factory in `test/factories/`
3. Write model tests in `test/models/`
4. Update database with `rails db:migrate`

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

## 🚀 Deployment Notes

- Uses Rails 8's solid components (Cache, Queue, Cable) - requires database
- Kamal deployment configuration included
- Docker support with Dockerfile
- PostgreSQL required in production

## 📝 Contributing

1. Follow Rails conventions and project structure
2. Write comprehensive tests for all new features
3. Use FactoryBot for complex test data scenarios
4. Ensure all tests pass before submitting PRs
5. Follow the existing code style and patterns

## 📚 Additional Resources

- [Rails 8.0 Release Notes](https://guides.rubyonrails.org/8_0_release_notes.html)
- [Rails API Documentation](https://api.rubyonrails.org/)
- [FactoryBot Documentation](https://thoughtbot.github.io/factory_bot/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

---

**Current Status**: ✅ Basic setup complete with hello world endpoint and comprehensive test suite
