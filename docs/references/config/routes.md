# Routes Configuration

**File**: `config/routes.rb`

## Purpose

Defines all HTTP routes for the Rails application. Uses RESTful conventions with API versioning under `/api/v1/`.

## Route Definitions

### API v1 Namespace

All API routes are namespaced under `api/v1`:

```ruby
namespace :api do
  namespace :v1 do
    # routes here
  end
end
```

### Available Endpoints

| Method | Path | Controller#Action | Purpose |
|--------|------|-------------------|---------|
| GET | `/api/v1/hello/index` | `hello#index` | Health check |
| POST | `/api/v1/translate` | `translation#translate` | Document translation |
| POST | `/api/v1/translate_text` | `translation#translate_text` | Text translation |
| GET | `/up` | `rails/health#show` | Rails health check |

## Route Details

### Hello Endpoint
```ruby
get "hello/index"
```
Simple GET endpoint for API health verification.

### Translation Endpoints
```ruby
post "translate", to: "translation#translate"
post "translate_text", to: "translation#translate_text"
```
POST endpoints for translation operations.

### Health Check
```ruby
get "up" => "rails/health#show", as: :rails_health_check
```
Built-in Rails health check at `/up` for load balancers and uptime monitors.

## URL Helpers

| Helper | Path |
|--------|------|
| `api_v1_hello_index_path` | `/api/v1/hello/index` |
| `api_v1_translate_path` | `/api/v1/translate` |
| `api_v1_translate_text_path` | `/api/v1/translate_text` |
| `rails_health_check_path` | `/up` |

## API Versioning

The `/api/v1/` namespace allows for future API versions:
- Current: `/api/v1/*`
- Future: `/api/v2/*` (when needed)

## Related Files

- [HelloController](../app/controllers/api/v1/hello_controller.md)
- [TranslationController](../app/controllers/api/v1/translation_controller.md)

