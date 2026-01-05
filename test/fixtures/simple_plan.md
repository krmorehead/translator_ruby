# Execution Plan: Add health check endpoint

## Goal

Add a /api/health endpoint that returns JSON status

## Milestone 1: Create Health Controller

Create a simple health check controller

### 1.1 - Create HealthController

**Intent**: Create a controller that responds to GET /api/health

**Details**:
- Create app/controllers/api/health_controller.rb
- Add show action that returns { status: "ok" }

**Tests**:
- GET /api/health returns 200
- Response body contains status: ok

---

## Milestone 2: Add Route

Add the route to config/routes.rb

### 2.1 - Add Health Route

**Intent**: Configure the route for health endpoint

**Details**:
- Add get "/api/health" route
- Point to health#show action

**Tests**:
- Route exists and is reachable

