# HelloController

**File**: `app/controllers/api/v1/hello_controller.rb`

## Purpose

Provides a simple health check endpoint that returns a JSON response with basic application information.

## Endpoints

### `GET /api/v1/hello/index`

Returns a JSON response confirming the API is running.

**Response**:
```json
{
  "message": "Hello World!",
  "status": "success",
  "timestamp": "2025-12-07T12:00:00.000Z",
  "version": "1.0.0"
}
```

## Implementation Details

| Method | Action | Purpose |
|--------|--------|---------|
| `index` | GET | Returns health check JSON |

## Response Fields

| Field | Type | Description |
|-------|------|-------------|
| `message` | String | Static greeting message |
| `status` | String | Always "success" for healthy response |
| `timestamp` | DateTime | Current server time (ISO 8601) |
| `version` | String | API version number |

## Usage

- Health checks for load balancers
- Uptime monitoring
- API connectivity verification

## Related Tests

- `test/controllers/api/v1/hello_controller_test.rb`


