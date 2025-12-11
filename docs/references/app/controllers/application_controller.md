# ApplicationController

**File**: `app/controllers/application_controller.rb`

## Purpose

Base controller for all API controllers in the application. Inherits from `ActionController::API` to provide a lightweight API-only controller without view rendering capabilities.

## Implementation

```ruby
class ApplicationController < ActionController::API
end
```

## Key Characteristics

- **API-only mode**: No view rendering, session handling, or CSRF protection
- **Lightweight**: Excludes middleware not needed for API applications
- **Inheritance**: All API controllers inherit from this base class

## Inherited Controllers

- `Api::V1::HelloController`
- `Api::V1::TranslationController`

## Notes

- Part of Rails' API-only application mode
- Can be extended with shared concerns (authentication, error handling, etc.)
- Currently minimal - serves as inheritance anchor for API controllers


