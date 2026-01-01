# Project Plan: Sisyphus Browser Interface

## Overview

Create a browser-based interface for the Sisyphus execution agent that leverages **existing tool infrastructure** and follows **React best practices** with proper component architecture. This interface enables project management, execution monitoring, and agent configuration through a clean, reusable component system.

**Key Design Principles:**
- **Reuse existing tools**: Leverage `FileTreeTool`, `ReadFileTool`, `GrepTool` instead of creating new services
- **Proper React architecture**: Presentational vs Container components, custom hooks, single data flow
- **OOP patterns everywhere**: Backend models follow strict validation, frontend follows component composition
- **Test-driven development**: Write tests first, maintain >90% coverage

---

## Architecture

### Backend Architecture

```
Controller (API Layer)
    ↓
ToolExecutionService (Tool Wrapper)
    ↓
Existing Tools (FileTreeTool, ReadFileTool, etc.)
```

**Key Insight**: We already have filesystem tools! No need for FileSystemService.
- `FileTreeTool` - Lists directory structures
- `ReadFileTool` - Reads file contents  
- `GrepTool` - Searches files
- Tools are already validated and tested

**New Services Needed:**
1. `ToolExecutionService` - Thin wrapper to execute tools from API layer
2. `ConfigurationService` - Manages GenericLlmClient configuration
3. `ExecutionOrchestrationService` - Manages SisyphusWorker lifecycle

### Frontend Architecture

```
Pages (Container Components)
    ↓
Custom Hooks (Business Logic)
    ↓
Store (Zustand)
    ↓
API Layer
```

**Component Hierarchy:**
- **Container Components**: Connect to store, handle logic
- **Presentational Components**: Pure, reusable, props-driven
- **Custom Hooks**: Encapsulate business logic, reusable across components
- **Single Data Flow**: State flows down, events flow up

**Frontend Patterns:**
- **Composition over inheritance**: Build complex UIs from simple components
- **Single Responsibility**: Each component does one thing well
- **Props validation**: Use PropTypes or TypeScript
- **Derived state**: Compute from single source of truth
- **Custom hooks**: Extract reusable logic (useExecution, useFileTree)

---

## Milestone 1: Backend - Tool Wrapper and Configuration

### 1.1 - Create ToolExecutionService

**Intent**: Thin service layer that wraps existing tools for API consumption. Handles tool instantiation and result formatting.

**Details**:
- Create `app/services/tool_execution_service.rb` as PORO
- Methods:
  - `execute_tool(tool_name, params)` → Returns standardized result
  - `list_directory(path, options = {})` → Uses FileTreeTool
  - `read_file(path)` → Uses ReadFileTool
  - `search_files(path, pattern)` → Uses GrepTool
- Tool mapping:
  ```ruby
  TOOL_MAP = {
    file_tree: FileTreeTool,
    read_file: ReadFileTool,
    grep: GrepTool
  }.freeze
  ```
- Standardize responses: `{success:, data:, error:}`
- Validate paths before tool execution
- Handle tool errors gracefully

**Tests** (`test/services/tool_execution_service_test.rb`):
- Test execute_tool calls FileTreeTool correctly
- Test execute_tool calls ReadFileTool correctly
- Test list_directory wraps FileTreeTool
- Test read_file wraps ReadFileTool
- Test search_files wraps GrepTool
- Test handles unknown tool names
- Test handles tool execution errors
- Test standardizes response format

**Files Created**:
- `app/services/tool_execution_service.rb`
- `test/services/tool_execution_service_test.rb`

---

### 1.2 - Create ConfigurationService

**Intent**: Manage GenericLlmClient configuration dynamically. Read, validate, and update capability settings.

**Details**:
- Create `app/services/configuration_service.rb` as PORO
- Create `app/models/configuration/agent_config.rb` (domain model)
- Create `app/models/configuration/capability_config.rb` (domain model)
- Methods:
  - `get_current_config` → Returns AgentConfig with CAPABILITIES
  - `validate_capability(config_hash)` → Validates capability settings
  - `get_environment_vars` → Returns LLM env vars (masked)
  - `test_connection(capability)` → Tests LLM endpoint
- AgentConfig attributes:
  - `capabilities` (hash of CapabilityConfig objects)
  - `environment` (hash of env vars, secrets masked)
- CapabilityConfig attributes:
  - `name` (string)
  - `model_name` (string)
  - `port` (integer, 1-65535)
  - `max_context` (integer, > 0)
  - `base_url` (string, ENV key)
- Validation:
  - Required fields present
  - Port in valid range
  - max_context positive integer
- Follow OOP patterns with strict validation
- Never expose raw API keys (mask with `***`)

**Tests** (`test/services/configuration_service_test.rb`, `test/models/configuration/*_test.rb`):
- Test get_current_config returns AgentConfig
- Test AgentConfig.to_h serializes correctly
- Test Capability Config validates required fields
- Test CapabilityConfig validates port range
- Test CapabilityConfig validates max_context
- Test get_environment_vars masks secrets
- Test test_connection validates endpoint
- Test validation failures raise appropriate errors

**Files Created**:
- `app/services/configuration_service.rb`
- `app/models/configuration/agent_config.rb`
- `app/models/configuration/capability_config.rb`
- `test/services/configuration_service_test.rb`
- `test/models/configuration/agent_config_test.rb`
- `test/models/configuration/capability_config_test.rb`

---

### 1.3 - Create ExecutionOrchestrationService

**Intent**: Manage Sisyphus execution lifecycle. Start executions, track progress, provide state snapshots.

**Details**:
- Create `app/services/execution_orchestration_service.rb` as PORO
- Create `app/models/execution/execution_state.rb` (domain model)
- Methods:
  - `start_execution(plan_path, project_path, config)` → execution_id
  - `get_execution_state(execution_id)` → ExecutionState
  - `list_executions(project_path)` → Array<ExecutionState>
  - `cancel_execution(execution_id)` → boolean
- ExecutionState attributes:
  - `execution_id` (string)
  - `plan_path` (string)
  - `project_path` (string)
  - `status` (symbol: :pending, :running, :complete, :failed)
  - `current_milestone` (string or nil)
  - `current_step` (string or nil)
  - `progress_percentage` (float, 0-100)
  - `files_changed` (array of paths)
  - `checkpoint_ids` (array of git hashes)
  - `started_at` (timestamp)
  - `completed_at` (timestamp or nil)
  - `error` (string or nil)
- Execution tracking:
  - Store in class variable: `@@executions = {}`
  - Track: `execution_id => {worker:, state:, started_at:}`
  - Clean up after 1 hour
- Thread-safe access (use Mutex)
- Follow OOP patterns

**Tests** (`test/services/execution_orchestration_service_test.rb`, `test/models/execution/execution_state_test.rb`):
- Test start_execution creates worker
- Test start_execution returns unique ID
- Test start_execution validates plan exists
- Test start_execution validates project path
- Test get_execution_state returns ExecutionState
- Test get_execution_state handles unknown ID
- Test list_executions returns all for project
- Test cancel_execution stops worker
- Test ExecutionState.to_h serialization
- Test ExecutionState validates attributes
- Test thread-safe concurrent access

**Files Created**:
- `app/services/execution_orchestration_service.rb`
- `app/models/execution/execution_state.rb`
- `test/services/execution_orchestration_service_test.rb`
- `test/models/execution/execution_state_test.rb`

---

## Milestone 2: Backend - Controller and Routes

### 2.1 - Create SisyphusController

**Intent**: REST API controller exposing tool services, configuration, and execution management.

**Details**:
- Create `app/controllers/sisyphus_controller.rb`
- Endpoints:
  - `GET /sisyphus` → Serves SPA (like dnd_chat#spa)
  - `POST /sisyphus/tools/execute` → Execute tool (file_tree, read_file, grep)
  - `GET /sisyphus/projects/:path/tree` → Get directory tree
  - `GET /sisyphus/projects/:path/file` → Read file contents
  - `POST /sisyphus/executions` → Start execution
  - `GET /sisyphus/executions/:id` → Get execution state
  - `DELETE /sisyphus/executions/:id` → Cancel execution
  - `GET /sisyphus/config` → Get agent config
  - `POST /sisyphus/config/test` → Test LLM connection
- Use services:
  - `ToolExecutionService` for file operations
  - `ConfigurationService` for config management
  - `ExecutionOrchestrationService` for executions
- Response format: `{success:, data:, error:}`
- HTTP status codes: 200 (success), 400 (bad request), 404 (not found), 500 (error)
- Strong parameters for input validation
- Follow patterns from [`app/controllers/project_planning_controller.rb`](app/controllers/project_planning_controller.rb)

**Tests** (`test/controllers/sisyphus_controller_test.rb`):
- Test spa serves frontend HTML
- Test POST /sisyphus/tools/execute calls ToolExecutionService
- Test GET /sisyphus/projects/:path/tree returns tree
- Test GET /sisyphus/projects/:path/file returns contents
- Test POST /sisyphus/executions starts execution
- Test POST /sisyphus/executions validates inputs
- Test GET /sisyphus/executions/:id returns state
- Test DELETE /sisyphus/executions/:id cancels
- Test GET /sisyphus/config returns configuration
- Test POST /sisyphus/config/test validates connection
- Test all endpoints handle errors gracefully

**Files Created**:
- `app/controllers/sisyphus_controller.rb`
- `test/controllers/sisyphus_controller_test.rb`

---

### 2.2 - Add Routes

**Details**:
- Update [`config/routes.rb`](config/routes.rb)
- Routes:
  ```ruby
  # Sisyphus browser interface
  get "/sisyphus", to: "sisyphus#spa"
  
  # Tool execution
  post "/sisyphus/tools/execute", to: "sisyphus#execute_tool"
  get "/sisyphus/projects/*path/tree", to: "sisyphus#get_directory_tree"
  get "/sisyphus/projects/*path/file", to: "sisyphus#read_file"
  
  # Execution management
  post "/sisyphus/executions", to: "sisyphus#create_execution"
  get "/sisyphus/executions/:id", to: "sisyphus#get_execution"
  delete "/sisyphus/executions/:id", to: "sisyphus#cancel_execution"
  
  # Configuration
  get "/sisyphus/config", to: "sisyphus#get_config"
  post "/sisyphus/config/test", to: "sisyphus#test_connection"
  ```

**Files Modified**:
- [`config/routes.rb`](config/routes.rb)

---

## Milestone 3: Frontend - Store, API, and Hooks

### 3.1 - Create sisyphusApi.js

**Intent**: API client for backend communication. Clean, testable functions.

**Details**:
- Create `frontend/src/api/sisyphusApi.js`
- Functions:
  ```javascript
  // Tool execution
  export const executeTool = (toolName, params) => { ... }
  export const getDirectoryTree = (path, options = {}) => { ... }
  export const readFile = (path) => { ... }
  
  // Execution management
  export const startExecution = (planPath, projectPath, config) => { ... }
  export const getExecution = (executionId) => { ... }
  export const cancelExecution = (executionId) => { ... }
  
  // Configuration
  export const getConfig = () => { ... }
  export const testConnection = (capability) => { ... }
  ```
- Error handling: throw errors with user-friendly messages
- Follow patterns from [`frontend/src/api/projectPlanApi.js`](frontend/src/api/projectPlanApi.js)
- Use `fetch` API

**Tests** (`frontend/src/api/__tests__/sisyphusApi.test.js`):
- Test executeTool posts correctly
- Test getDirectoryTree fetches tree
- Test readFile fetches content
- Test startExecution posts data
- Test getExecution fetches state
- Test cancelExecution deletes
- Test getConfig fetches config
- Test error handling

**Files Created**:
- `frontend/src/api/sisyphusApi.js`
- `frontend/src/api/__tests__/sisyphusApi.test.js`

---

### 3.2 - Create sisyphusStore.js with Single Data Flow

**Intent**: Zustand store as single source of truth. Derived state computed from base state.

**Details**:
- Create `frontend/src/store/sisyphusStore.js`
- **Base State** (stored):
  ```javascript
  {
    // Project state
    currentPath: "",
    directoryTree: null,
    selectedFile: null,
    fileContent: "",
    
    // Execution state
    executions: {},  // { id: ExecutionState }
    activeExecutionId: null,
    
    // Config state
    agentConfig: null,
    
    // UI state
    loading: { tree: false, file: false, execution: false, config: false },
    errors: { tree: null, file: null, execution: null, config: null }
  }
  ```
- **Derived State** (computed):
  ```javascript
  // Computed in selectors, not stored
  activeExecution: () => state.executions[state.activeExecutionId],
  isExecutionRunning: () => activeExecution?.status === 'running',
  executionProgress: () => activeExecution?.progress_percentage || 0
  ```
- **Actions** (update state):
  ```javascript
  // Project actions
  setCurrentPath(path)
  fetchDirectoryTree(path, options)
  selectFile(path)
  fetchFileContent(path)
  
  // Execution actions
  startExecution(planPath, projectPath, config)
  fetchExecution(executionId)
  setActiveExecution(executionId)
  cancelExecution(executionId)
  startExecutionPolling(executionId)
  stopExecutionPolling()
  
  // Config actions
  fetchConfig()
  testConnection(capability)
  
  // Reset
  reset()
  ```
- **Single Data Flow**:
  - State → Component (via selectors)
  - User Event → Action → API → State Update
  - Never mutate state directly
- Follow patterns from [`frontend/src/store/projectPlanStore.js`](frontend/src/store/projectPlanStore.js)
- Use immer for immutable updates (built into Zustand)

**Tests** (`frontend/src/store/__tests__/sisyphusStore.test.js`):
- Test initial state
- Test setCurrentPath updates state
- Test fetchDirectoryTree fetches and updates
- Test derived state computes correctly
- Test startExecution creates execution
- Test polling starts and stops
- Test error handling
- Test reset clears state

**Files Created**:
- `frontend/src/store/sisyphusStore.js`
- `frontend/src/store/__tests__/sisyphusStore.test.js`

---

### 3.3 - Create Custom Hooks

**Intent**: Extract reusable business logic into custom hooks. Promote code reuse and testability.

**Details**:
- Create `frontend/src/hooks/useExecution.js`:
  ```javascript
  export const useExecution = (executionId) => {
    const execution = useSisyphusStore(state => state.executions[executionId]);
    const isRunning = execution?.status === 'running';
    const progress = execution?.progress_percentage || 0;
    
    useEffect(() => {
      if (isRunning) {
        // Start polling
        const interval = startPolling(executionId);
        return () => clearInterval(interval);
      }
    }, [isRunning, executionId]);
    
    return { execution, isRunning, progress };
  };
  ```
- Create `frontend/src/hooks/useFileTree.js`:
  ```javascript
  export const useFileTree = (path) => {
    const tree = useSisyphusStore(state => state.directoryTree);
    const loading = useSisyphusStore(state => state.loading.tree);
    const error = useSisyphusStore(state => state.errors.tree);
    const fetchTree = useSisyphusStore(state => state.fetchDirectoryTree);
    
    useEffect(() => {
      if (path) {
        fetchTree(path);
      }
    }, [path, fetchTree]);
    
    return { tree, loading, error };
  };
  ```
- Create `frontend/src/hooks/useConfig.js`:
  ```javascript
  export const useConfig = () => {
    const config = useSisyphusStore(state => state.agentConfig);
    const loading = useSisyphusStore(state => state.loading.config);
    const fetchConfig = useSisyphusStore(state => state.fetchConfig);
    
    useEffect(() => {
      if (!config) {
        fetchConfig();
      }
    }, [config, fetchConfig]);
    
    return { config, loading };
  };
  ```
- **Benefits**:
  - Encapsulate logic
  - Reusable across components
  - Testable in isolation
  - Single Responsibility Principle

**Tests** (`frontend/src/hooks/__tests__/*.test.js`):
- Test useExecution returns execution state
- Test useExecution starts polling when running
- Test useFileTree fetches tree on mount
- Test useConfig fetches config on mount
- Test hooks handle loading and error states

**Files Created**:
- `frontend/src/hooks/useExecution.js`
- `frontend/src/hooks/useFileTree.js`
- `frontend/src/hooks/useConfig.js`
- `frontend/src/hooks/__tests__/useExecution.test.js`
- `frontend/src/hooks/__tests__/useFileTree.test.js`
- `frontend/src/hooks/__tests__/useConfig.test.js`

---

## Milestone 4: Frontend - Presentational Components

### 4.1 - Create Base Presentational Components

**Intent**: Small, reusable, pure components. No store connection, props-driven.

**Details**:
- Create `frontend/src/components/presentational/`:
  - **Button.jsx**: Reusable button with variants (primary, secondary, danger)
  - **LoadingSpinner.jsx**: Loading indicator
  - **ErrorBanner.jsx**: Error display banner
  - **ProgressBar.jsx**: Progress visualization
  - **Card.jsx**: Container card component
  - **Badge.jsx**: Status badge (running, complete, failed)
  - **Icon.jsx**: Icon wrapper component
- **Principles**:
  - Pure functions (same props → same output)
  - No side effects
  - Props validation (PropTypes)
  - Composition over configuration
  - Single Responsibility

**Example** (`Button.jsx`):
```javascript
export const Button = ({ 
  children, 
  variant = 'primary', 
  onClick, 
  disabled = false,
  ...props 
}) => {
  return (
    <button 
      className={`btn btn-${variant}`}
      onClick={onClick}
      disabled={disabled}
      {...props}
    >
      {children}
    </button>
  );
};

Button.propTypes = {
  children: PropTypes.node.isRequired,
  variant: PropTypes.oneOf(['primary', 'secondary', 'danger']),
  onClick: PropTypes.func,
  disabled: PropTypes.bool
};
```

**Tests** (`frontend/src/components/presentational/__tests__/*.test.jsx`):
- Test Button renders with correct class
- Test Button calls onClick
- Test Button disabled state
- Test ProgressBar displays percentage
- Test ErrorBanner displays message
- Test Badge shows correct status

**Files Created**:
- `frontend/src/components/presentational/Button.jsx`
- `frontend/src/components/presentational/LoadingSpinner.jsx`
- `frontend/src/components/presentational/ErrorBanner.jsx`
- `frontend/src/components/presentational/ProgressBar.jsx`
- `frontend/src/components/presentational/Card.jsx`
- `frontend/src/components/presentational/Badge.jsx`
- `frontend/src/components/presentational/Icon.jsx`
- `frontend/src/components/presentational/__tests__/*.test.jsx` (7 test files)

---

### 4.2 - Create Project Components

**Intent**: Components for project browsing and file navigation.

**Details**:
- `DirectoryTree.jsx` (presentational):
  - Props: `tree`, `onSelectDirectory`, `onSelectFile`, `selectedPath`
  - Recursive rendering of tree structure
  - Expandable/collapsible directories
  - File/directory icons
  - Highlight selected item
- `FileViewer.jsx` (presentational):
  - Props: `content`, `filePath`, `language`
  - Syntax highlighted code display
  - Line numbers
  - Copy to clipboard button
- `PathInput.jsx` (presentational):
  - Props: `value`, `onChange`, `onBrowse`
  - Input for manual path entry
  - Browse button

**Tests**:
- Test DirectoryTree renders tree structure
- Test DirectoryTree calls onSelectDirectory
- Test DirectoryTree expands/collapses
- Test FileViewer displays content
- Test FileViewer syntax highlights
- Test PathInput calls onChange

**Files Created**:
- `frontend/src/components/presentational/DirectoryTree.jsx`
- `frontend/src/components/presentational/FileViewer.jsx`
- `frontend/src/components/presentational/PathInput.jsx`
- `frontend/src/components/presentational/__tests__/DirectoryTree.test.jsx`
- `frontend/src/components/presentational/__tests__/FileViewer.test.jsx`
- `frontend/src/components/presentational/__tests__/PathInput.test.jsx`

---

### 4.3 - Create Execution Components

**Intent**: Components for execution monitoring and progress display.

**Details**:
- `ExecutionCard.jsx` (presentational):
  - Props: `execution`, `onSelect`, `onCancel`
  - Displays execution summary
  - Status badge, progress bar
  - Action buttons
- `StepList.jsx` (presentational):
  - Props: `steps`, `currentStep`
  - Lists steps with status icons
  - Highlight current step
  - Expandable step details
- `LogViewer.jsx` (presentational):
  - Props: `logs`, `autoScroll`
  - Displays log entries
  - Timestamps, log levels
  - Auto-scroll to bottom
- `ThoughtsViewer.jsx` (presentational):
  - Props: `thoughts`, `memories`
  - Displays LLM thoughts
  - Memory sections
  - Expandable entries

**Tests**:
- Test ExecutionCard displays execution
- Test ExecutionCard calls onCancel
- Test StepList renders steps
- Test StepList highlights current
- Test LogViewer displays logs
- Test LogViewer auto-scrolls
- Test ThoughtsViewer displays thoughts

**Files Created**:
- `frontend/src/components/presentational/ExecutionCard.jsx`
- `frontend/src/components/presentational/StepList.jsx`
- `frontend/src/components/presentational/LogViewer.jsx`
- `frontend/src/components/presentational/ThoughtsViewer.jsx`
- `frontend/src/components/presentational/__tests__/*.test.jsx` (4 test files)

---

### 4.4 - Create Config Components

**Intent**: Components for configuration management.

**Details**:
- `CapabilityCard.jsx` (presentational):
  - Props: `capability`, `onTest`
  - Displays capability settings
  - Expandable details
  - Test connection button
- `CapabilityList.jsx` (presentational):
  - Props: `capabilities`, `onSelect`
  - Lists all capabilities
  - Click to expand/edit

**Tests**:
- Test CapabilityCard displays settings
- Test CapabilityCard calls onTest
- Test CapabilityList renders list
- Test CapabilityList calls onSelect

**Files Created**:
- `frontend/src/components/presentational/CapabilityCard.jsx`
- `frontend/src/components/presentational/CapabilityList.jsx`
- `frontend/src/components/presentational/__tests__/CapabilityCard.test.jsx`
- `frontend/src/components/presentational/__tests__/CapabilityList.test.jsx`

---

## Milestone 5: Frontend - Container Components

### 5.1 - Create ProjectBrowserContainer

**Intent**: Container component connecting ProjectBrowser to store and hooks.

**Details**:
- Create `frontend/src/components/containers/ProjectBrowserContainer.jsx`
- Uses `useFileTree` hook
- Connects to sisyphusStore actions
- Handles user interactions
- Renders presentational components:
  - `PathInput`
  - `DirectoryTree`
  - `FileViewer`
- **Responsibilities**:
  - Fetch data
  - Handle events
  - Manage local UI state (e.g., expanded nodes)
- **Composition**:
```javascript
export const ProjectBrowserContainer = () => {
  const [path, setPath] = useState("");
  const { tree, loading, error } = useFileTree(path);
  const fetchTree = useSisyphusStore(state => state.fetchDirectoryTree);
  const selectFile = useSisyphusStore(state => state.selectFile);
  
  const handleBrowse = () => {
    fetchTree(path);
  };
  
  const handleSelectFile = (filePath) => {
    selectFile(filePath);
  };
  
  return (
    <Card>
      <PathInput 
        value={path} 
        onChange={setPath} 
        onBrowse={handleBrowse} 
      />
      {loading && <LoadingSpinner />}
      {error && <ErrorBanner message={error} />}
      {tree && (
        <DirectoryTree 
          tree={tree} 
          onSelectFile={handleSelectFile} 
        />
      )}
    </Card>
  );
};
```

**Tests** (`frontend/src/components/containers/__tests__/ProjectBrowserContainer.test.jsx`):
- Test fetches tree on mount
- Test handleBrowse calls fetchTree
- Test handleSelectFile calls selectFile
- Test displays loading state
- Test displays error state
- Test renders DirectoryTree with data

**Files Created**:
- `frontend/src/components/containers/ProjectBrowserContainer.jsx`
- `frontend/src/components/containers/__tests__/ProjectBrowserContainer.test.jsx`

---

### 5.2 - Create ExecutionMonitorContainer

**Intent**: Container for execution monitoring.

**Details**:
- Create `frontend/src/components/containers/ExecutionMonitorContainer.jsx`
- Uses `useExecution` hook
- Renders:
  - `ExecutionCard`
  - `ProgressBar`
  - `StepList`
  - `LogViewer`
- Handles:
  - Execution selection
  - Cancellation
  - Progress polling

**Tests**:
- Test fetches execution on mount
- Test starts polling when running
- Test handleCancel calls cancelExecution
- Test displays execution state
- Test displays progress

**Files Created**:
- `frontend/src/components/containers/ExecutionMonitorContainer.jsx`
- `frontend/src/components/containers/__tests__/ExecutionMonitorContainer.test.jsx`

---

### 5.3 - Create ConfigEditorContainer

**Intent**: Container for configuration editing.

**Details**:
- Create `frontend/src/components/containers/ConfigEditorContainer.jsx`
- Uses `useConfig` hook
- Renders:
  - `CapabilityList`
  - `CapabilityCard`
- Handles:
  - Config fetching
  - Connection testing

**Tests**:
- Test fetches config on mount
- Test handleTest calls testConnection
- Test displays config
- Test displays loading state

**Files Created**:
- `frontend/src/components/containers/ConfigEditorContainer.jsx`
- `frontend/src/components/containers/__tests__/ConfigEditorContainer.test.jsx`

---

### 5.4 - Create SisyphusPage

**Intent**: Main page component orchestrating all containers.

**Details**:
- Create `frontend/src/components/SisyphusPage.jsx`
- Layout:
  ```
  +----------------------------------+
  |  Header (Title, Nav)             |
  +--------+----------------+--------+
  | Project| Execution      | Config |
  | Browser| Monitor        | Editor |
  |        |                | Tabs:  |
  |        |                | -Config|
  |        |                | -Thoughts|
  |        |                | -Files |
  +--------+----------------+--------+
  ```
- Three-column layout (30% / 40% / 30%)
- Tabbed right panel
- Responsive (stack on mobile)
- Renders container components

**Tests**:
- Test renders all containers
- Test layout responsive
- Test tab switching

**Files Created**:
- `frontend/src/components/SisyphusPage.jsx`
- `frontend/src/components/sisyphus.css`
- `frontend/src/components/__tests__/SisyphusPage.test.jsx`

---

## Milestone 6: Integration and Polish

### 6.1 - Update App.jsx

**Details**:
- Update [`frontend/src/App.jsx`](frontend/src/App.jsx)
- Add `/sisyphus` route
- Render `SisyphusPage`

**Files Modified**:
- [`frontend/src/App.jsx`](frontend/src/App.jsx)

---

### 6.2 - Integration Tests

**Intent**: Test complete flows end-to-end.

**Details**:
- Create `test/integration/sisyphus_browser_integration_test.rb`
- Test scenarios:
  - Browse directory → View file
  - Start execution → Monitor progress
  - View configuration → Test connection
- Test error paths
- Test real tool execution

**Files Created**:
- `test/integration/sisyphus_browser_integration_test.rb`

---

### 6.3 - Documentation

**Details**:
- Create `docs/references/sisyphus_browser_interface.md`
- Document:
  - Architecture
  - API endpoints
  - Component hierarchy
  - Usage guide

**Files Created**:
- `docs/references/sisyphus_browser_interface.md`

---

## File Summary

### Backend (16 files)

**Services** (3 files):
- `app/services/tool_execution_service.rb`
- `app/services/configuration_service.rb`
- `app/services/execution_orchestration_service.rb`

**Models** (3 files):
- `app/models/configuration/agent_config.rb`
- `app/models/configuration/capability_config.rb`
- `app/models/execution/execution_state.rb`

**Controllers** (1 file):
- `app/controllers/sisyphus_controller.rb`

**Tests** (9 files):
- `test/services/tool_execution_service_test.rb`
- `test/services/configuration_service_test.rb`
- `test/services/execution_orchestration_service_test.rb`
- `test/models/configuration/agent_config_test.rb`
- `test/models/configuration/capability_config_test.rb`
- `test/models/execution/execution_state_test.rb`
- `test/controllers/sisyphus_controller_test.rb`
- `test/integration/sisyphus_browser_integration_test.rb`

**Modified** (1 file):
- [`config/routes.rb`](config/routes.rb)

### Frontend (42 files)

**API/Store/Hooks** (8 files):
- `frontend/src/api/sisyphusApi.js`
- `frontend/src/api/__tests__/sisyphusApi.test.js`
- `frontend/src/store/sisyphusStore.js`
- `frontend/src/store/__tests__/sisyphusStore.test.js`
- `frontend/src/hooks/useExecution.js`
- `frontend/src/hooks/useFileTree.js`
- `frontend/src/hooks/useConfig.js`
- `frontend/src/hooks/__tests__/*.test.js` (3 files)

**Presentational Components** (18 files):
- Base: Button, LoadingSpinner, ErrorBanner, ProgressBar, Card, Badge, Icon (7 + 7 tests)
- Project: DirectoryTree, FileViewer, PathInput (3 + 3 tests)
- Execution: ExecutionCard, StepList, LogViewer, ThoughtsViewer (4 + 4 tests)
- Config: CapabilityCard, CapabilityList (2 + 2 tests)

**Container Components** (6 files):
- ProjectBrowserContainer (1 + 1 test)
- ExecutionMonitorContainer (1 + 1 test)
- ConfigEditorContainer (1 + 1 test)

**Pages** (3 files):
- SisyphusPage (1 + 1 test + 1 css)

**Modified** (1 file):
- [`frontend/src/App.jsx`](frontend/src/App.jsx)

### Documentation (1 file):
- `docs/references/sisyphus_browser_interface.md`

**Total: 58 new files, 2 modified files**

---

## Key Principles Applied

### Backend - OOP Patterns

1. **No hash-based state**: All domain entities are proper classes
2. **Strict validation**: Fail-fast with descriptive errors
3. **Type checking**: Validate types in initializers
4. **Serialization**: Full to_h/from_h support
5. **Single Responsibility**: Each class/service does one thing
6. **Composition**: Build complex behavior from simple parts

### Frontend - React Best Practices

1. **Presentational vs Container**: Clear separation of concerns
2. **Custom Hooks**: Extract and reuse business logic
3. **Single Data Flow**: State flows down, events flow up
4. **Derived State**: Compute from single source of truth
5. **Composition**: Build UIs from small, reusable components
6. **Props Validation**: Type-check all props
7. **Pure Components**: Same props → same output
8. **Single Responsibility**: Each component does one thing

### Testing Strategy

1. **Test-Driven**: Write tests first
2. **Unit Tests**: Test each component/service in isolation
3. **Integration Tests**: Test complete workflows
4. **No Mocking**: Use real tools and services
5. **Coverage >90%**: Comprehensive test coverage

---

## Success Criteria

- [ ] Browse filesystem using existing FileTreeTool
- [ ] Read files using existing ReadFileTool
- [ ] Start Sisyphus executions
- [ ] Monitor execution progress in real-time
- [ ] View execution thoughts and memories
- [ ] View agent configuration
- [ ] Test LLM connections
- [ ] Cancel running executions
- [ ] All components are pure and reusable
- [ ] Custom hooks encapsulate business logic
- [ ] Store follows single data flow
- [ ] All tests passing (>90% coverage)
- [ ] No linter errors
- [ ] Integration tests validate full workflow

---

## Implementation Order

1. **Backend Foundation** (Milestone 1-2): Services, models, controller
2. **Frontend Foundation** (Milestone 3): API, store, hooks
3. **Presentational Layer** (Milestone 4): Pure components
4. **Container Layer** (Milestone 5): Connected components, page
5. **Integration** (Milestone 6): Tests, documentation

---

## Notes

- **Leverage existing tools**: Don't duplicate FileTreeTool, ReadFileTool, etc.
- **React patterns**: Presentational/Container split makes components reusable
- **Custom hooks**: Extract logic for testing and reuse
- **Single data flow**: Makes state changes predictable and debuggable
- **Composition**: Build complex UIs from simple, tested pieces
- **Test everything**: Backend follows TDD, frontend tests all components

