# Project Plan: DnD Chat Workflow Refactor

## Overview

Refactor the DnD Chat Controller to follow a clean separation of concerns. The controller will become a thin delegation layer that receives payloads, initializes the orchestrator, delegates to the workflow, and serializes results. Business logic moves into a workflow class hierarchy with a minimal abstract contract. A new Prompt abstraction handles all LLM interaction, allowing different prompts to use different models.

## Goals

- Controller reduced to: receive payload, init orchestrator, delegate, serialize result
- BaseWorkflow abstract class with minimal contract (setup and execute only)
- Orchestrator is workflow-agnostic, only calls setup and execute on any workflow
- Prompt class abstracts all LLM interaction with per-prompt model selection
- Each prompt type can specify its own model via environment variable
- Workflow passes tool schemas to prompts; prompts serialize them for the LLM
- All DnD-specific logic (actions, consequences, narrative) stays inside the workflow
- No hardcoded switch/case statements for tool selection or argument normalization

## Testing Philosophy

**CRITICAL: No mocking or stubbing of any kind.** All tests must exercise real code paths:
- Use real LLM calls when credentials are configured
- Use real file I/O with test sandbox directories
- Use real tool execution through ToolCallService
- Integration tests exercise the full stack

---

## Milestone 1 - Build the Prompt Abstraction

Establish the Prompt class that handles all LLM interaction with per-prompt model configuration.

### 1.1 - Create BasePrompt Class

**Intent**: Create an abstract base class for prompts that encapsulates LLM interaction. Each prompt type can specify its own model, system prompt, and response format. This replaces manual OpenAI client usage throughout the codebase and provides a consistent pattern for all LLM interactions.

**Details**:
- Create at `app/prompts/base_prompt.rb`
- Abstract methods that subclasses must implement:
  - A method to return the system prompt string
  - A method to return the JSON schema for structured responses, or nil for freeform text
- Concrete methods provided by the base class:
  - A method to return the model name, defaulting to the LLM_MODEL environment variable, but overridable by subclasses
  - A method to execute the prompt, sending it to the LLM and returning the parsed response
  - A method to format a context hash into a prompt-appropriate string
  - A method to serialize an array of tool schemas into LLM-ready format for inclusion in prompts
  - A method to access the tools passed during construction
- Constructor accepts:
  - An optional array of tool schemas (passed from workflow when needed)
  - An optional OpenAI client for dependency injection during testing
- If no client is provided, create one using environment variables (following the pattern in the existing openai initializer)
- When a response schema is present, parse the LLM response as structured JSON
- When no response schema is present, return the raw text response
- Include meaningful error messages for LLM failures

**Tests**:
- Test that abstract methods raise NotImplementedError when called directly
- Test that the model method returns the environment variable default when not overridden
- Test that execute sends a request to the LLM and returns the response
- Test structured JSON response parsing when a schema is provided
- Test freeform text response when no schema is provided
- Test context formatting produces expected string output
- Test error handling when LLM returns an error
- Test that the tools accessor returns the tools passed to the constructor
- Test that serialize_tools produces valid LLM-ready format

---

### 1.2 - Create ActionDetectionPrompt

**Intent**: Create a prompt type for detecting discrete actions from user input. This prompt analyzes what the user wants to do and maps their intent to available tools. The workflow passes tool schemas to this prompt so it knows what actions are possible.

**Details**:
- Create at `app/prompts/action_detection_prompt.rb`
- Extend BasePrompt
- The workflow must pass tools to the constructor; this prompt requires them
- Override the model method to use the ACTION_DETECTION_MODEL environment variable, falling back to the default LLM_MODEL if not set
- The system prompt should:
  - Instruct the LLM to analyze user input and identify discrete actions the user wants to perform
  - Include the serialized tool information so the LLM knows what tools are available
  - Explain how to map user intent to specific tool calls with appropriate arguments
  - Handle edge cases: if input is purely conversational with no actions, return an empty array
  - Handle ambiguous input by selecting the most likely single action
  - Handle multi-part input by returning multiple actions in order of execution
- The response schema should define an array of action objects, where each object has:
  - A field for the portion of the user prompt this action relates to
  - A field for the tool name (the allowed values should be built from the passed tools)
  - A field for the arguments hash to pass to the tool
- The format_context method should include current scene and memory context along with the serialized tool information
- The execute method returns an array of hashes that can be converted to ActionRecord objects

**Tests**:
- Test that constructing without tools raises an error or produces an error state
- Test that the system prompt includes information about all passed tools
- Test that the response schema limits tool_name to only the passed tool names
- Test that execute returns an array of action hashes
- Test that purely conversational input returns an empty array
- Test that multi-part input (like "search the room and pick up the sword") returns multiple actions
- Test that context formatting includes both scene context and tool information

---

### 1.3 - Create NarrativePrompt

**Intent**: Create a prompt type for generating DM-voice narrative from action results. This prompt uses a model suited for creative writing and produces the final response text shown to the user.

**Details**:
- Create at `app/prompts/narrative_prompt.rb`
- Extend BasePrompt
- Does not require tools (narrative generation doesn't need tool schemas)
- Override the model method to use the NARRATIVE_MODEL environment variable, falling back to the default LLM_MODEL if not set
- The system prompt should:
  - Instruct the LLM to act as a Dungeon Master narrating the results of the player's actions
  - Weave action results and consequences into a cohesive, immersive narrative
  - Maintain a story-focused tone appropriate for tabletop RPG narration
  - Never mention game mechanics, dice rolls, tool names, or technical details
  - Keep responses concise, typically 2-4 sentences
- The response schema should be nil, indicating freeform text response
- The format_context method should include:
  - The list of completed actions with their results and consequences
  - Current scene context from memory
  - Recent conversation history for continuity
- The execute method returns a narrative string

**Tests**:
- Test that the model method uses the narrative-specific environment variable
- Test that the system prompt establishes the DM voice and tone
- Test that the response schema is nil (freeform text)
- Test that execute returns a string narrative
- Test that context formatting includes action results and consequences
- Test that generated narratives do not contain mechanical references (dice, tools, etc.)

---

### 1.4 - Create OutcomePrompt

**Intent**: Create a prompt type for determining the story outcomes of an executed action. This bridges the gap between mechanical tool results and narrative-relevant outcomes.

**Details**:
- Create at `app/prompts/outcome_prompt.rb`
- Extend BasePrompt
- Does not require tools
- Override the model method to use the CONSEQUENCE_MODEL environment variable, falling back to the default LLM_MODEL if not set
- The system prompt should:
  - Instruct the LLM to determine the narrative outcome of an action
  - Consider what action was performed, what the tool result was, and the current story context
  - Return a brief outcome description (1-2 sentences)
  - Focus on story impact rather than mechanical outcomes
  - Handle failed tool results by describing what went wrong in story terms
- The response schema should define an object with a single consequence field containing the consequence text
- The format_context method should include:
  - The action that was performed (tool name, arguments, prompt reference)
  - The tool result (success/failure and result data)
  - Current scene and story context
- The execute method returns a hash containing the consequence text

**Tests**:
- Test that outcomes are story-focused, not mechanical
- Test that the response schema defines the expected structure
- Test handling of successful tool results
- Test handling of failed tool results
- Test that context includes both the action and the result

---

## Milestone 2 - Build the Workflow Abstraction

Establish the base workflow class with minimal contract and the orchestrator.

### 2.1 - Create BaseWorkflow Abstract Class

**Intent**: Create an abstract base class with a minimal contract that the orchestrator uses. The workflow handles its own internal logic however it sees fit; the orchestrator only cares about setup and execute. This enables different workflow types to be used interchangeably.

**Details**:
- Create at `app/services/base_workflow.rb`
- The orchestrator contract consists of only these methods:
  - A setup method that accepts prompt, conversation, and sandbox_path as keyword arguments
  - An execute method that runs the workflow logic
  - A result accessor that returns the workflow result after execution
  - A complete? predicate that returns true if the workflow finished successfully
  - A failed? predicate that returns true if the workflow failed
  - An error accessor that returns the error message if failed, nil otherwise
- The setup method should store the inputs and return self to allow method chaining
- The execute method is abstract and must be implemented by subclasses
- The constructor takes no required arguments; inputs come through setup
- Include a class-level method for the workflow name (for identification/logging)
- Subclasses manage their own internal state however they see fit
- Subclasses can accept additional constructor arguments for dependencies (like tool_call_service)

**Tests**:
- Test that calling execute on BaseWorkflow directly raises NotImplementedError
- Test that setup stores the prompt, conversation, and sandbox_path
- Test that setup returns self for method chaining
- Test that complete? and failed? return the correct boolean values based on state
- Test that error returns nil when the workflow has not failed
- Test that the workflow_name class method is accessible

---

### 2.2 - Create WorkflowState Value Object

**Intent**: Create an immutable value object that workflows can use internally to track their state. This is optional infrastructure for workflow implementations, not part of the orchestrator contract.

**Details**:
- Create at `app/models/workflow_state.rb`
- Define status constants for PENDING, RUNNING, COMPLETE, and FAILED
- Support the following attributes:
  - status - the current state as a symbol
  - prompt - the original user prompt string
  - data - a hash for workflow-specific data (actions, narrative, etc.)
  - error - an error message string if failed, nil otherwise
- Use keyword arguments with sensible defaults (status defaults to PENDING, data defaults to empty hash)
- Implement a "with" method for immutable updates that returns a new instance with the specified changes
- Implement predicate methods for each status (complete?, failed?, pending?, running?)
- Implement a to_h method for serialization

**Tests**:
- Test initialization with all parameters
- Test initialization with only defaults
- Test that the "with" method returns a new instance with updated values
- Test that the "with" method does not mutate the original instance
- Test that each predicate method returns the correct value for each status
- Test that to_h produces the expected hash structure

---

### 2.3 - Create ActionRecord Value Object

**Intent**: Create a value object representing a single detected action. This is used internally by the DnD workflow to track actions through detection, execution, and consequence resolution.

**Details**:
- Create at `app/models/action_record.rb`
- Support the following attributes:
  - id - a unique identifier (UUID format)
  - prompt_reference - the portion of the user prompt this action relates to
  - tool_name - the name of the tool to execute
  - arguments - a hash of arguments to pass to the tool
  - status - one of pending, executed, or failed
  - result - the tool execution result (nil until executed)
  - consequence - the resolved consequence text (nil until resolved)
  - error - an error message if the action failed
  - timestamp - when the action was detected
- If no id is provided, generate a UUID automatically
- If no timestamp is provided, use the current time
- Implement a "with" method for immutable updates
- Implement a to_h method for serialization (used when storing in ActionsMemory)

**Tests**:
- Test initialization with required parameters (tool_name, arguments)
- Test that UUID is auto-generated when not provided
- Test that timestamp defaults to current time when not provided
- Test that the "with" method returns a new instance with updated values
- Test that to_h serializes all attributes correctly

---

### 2.4 - Create WorkflowOrchestrator

**Intent**: Create the orchestrator that manages workflow execution. The orchestrator is completely workflow-agnostic—it only calls setup and execute. It does not know or care about what happens inside the workflow.

**Details**:
- Create at `app/services/workflow_orchestrator.rb`
- The constructor accepts a workflow object
- The constructor should validate that the workflow responds to the required contract methods (setup, execute, result, complete?, failed?, error)
- If the workflow does not meet the contract, raise a WorkflowError with a descriptive message
- Provide a process method that accepts prompt, conversation, and sandbox_path as keyword arguments
- The process method should:
  1. Call setup on the workflow with the provided arguments
  2. Call execute on the workflow
  3. Return the workflow (the caller can then check result, complete?, failed?, error)
- The orchestrator does not manage state—the workflow manages its own state
- The orchestrator does not catch exceptions from execute; they propagate to the caller

**Tests**:
- Test that the constructor accepts a valid workflow
- Test that the constructor rejects objects missing required methods
- Test that process calls setup with the correct arguments
- Test that process calls execute after setup
- Test that process returns the workflow object
- Test that failed workflows can be detected via the returned workflow's failed? method

---

## Milestone 3 - Implement DndChatWorkflow

Implement the DnD-specific workflow that uses prompts to detect actions, execute tools, and generate narrative.

### 3.1 - Create ActionsMemory Type

**Intent**: Create a new memory type to store detected and executed actions. This enables the inspector view to show action history and provides an audit trail for debugging.

**Details**:
- Create at `app/models/memories/actions_memory.rb`
- Inherit from Memories::BaseMemory
- Set the section_name to "actions"
- Add an ACTIONS constant with value "actions" to MemoryKinds
- Register the new memory type in Memories::Registry::ALL
- Default value is an empty array
- Entries in this section store serialized ActionRecord objects (via to_h)

**Tests**:
- Test that section_name returns "actions"
- Test that default returns an empty array
- Test that the memory type is registered in the Registry
- Test that MemoryStore correctly recognizes and handles the actions section

---

### 3.2 - Implement DndChatWorkflow

**Intent**: Refactor DndChatWorkflow to extend BaseWorkflow and implement the full DnD chat logic using prompts. This is where all DnD-specific behavior lives.

**Details**:
- Modify `app/services/dnd_chat_workflow.rb`
- Extend BaseWorkflow
- Set workflow_name to "dnd_chat"
- The constructor should accept an optional tool_call_service parameter (default to a new ToolCallService instance)
- The constructor should accept an optional memory_store_class parameter for testing (default to MemoryStore)
- Keep the existing DEFAULT_SYSTEM_PROMPT constant for reference and potential reuse
- Implement the execute method with the following logic:
  1. Create a MemoryStore instance using the sandbox_path from setup
  2. Get the list of available DnD tools from the tool_call_service
  3. Detect actions by creating an ActionDetectionPrompt (passing the tools) and executing it with the user prompt and context from memory
  4. Convert the detection results to ActionRecord objects with pending status
  5. If no actions were detected, skip to narrative generation with an appropriate context
  6. For each pending action:
     a. Execute the tool via tool_call_service, passing the tool name and arguments
     b. Update the action record with the result and executed/failed status
     c. Create an OutcomePrompt and execute it to determine the story consequence
     d. Update the action record with the consequence
     e. Store the completed action in ActionsMemory
  7. Create a NarrativePrompt and execute it with all completed actions and context
  8. Set the internal state to complete with a result containing:
     - The narrative text
     - The list of processed actions
     - The updated conversation (with assistant message added)
  9. If any step fails, set the internal state to failed with an appropriate error message
- Use WorkflowState internally to track progress through these steps

**Tests**:
- Test that the workflow extends BaseWorkflow
- Test that execute passes tools to the ActionDetectionPrompt
- Test that execute detects actions from the prompt
- Test that execute runs the appropriate tool for each detected action
- Test that execute resolves consequences for each executed action
- Test that execute generates a narrative from all completed actions
- Test that execute handles the case where no actions are detected
- Test that execute handles tool failures gracefully (marks action as failed, continues or fails workflow appropriately)
- Test that executed actions are stored in ActionsMemory
- Test that the result contains narrative and actions after successful completion
- Test that a failed workflow has the error message set

---

### 3.3 - Define Workflow Result Structure

**Intent**: Specify the exact structure of the result returned by the DndChatWorkflow so that the serializer knows what to expect.

**Details**:
- The workflow result should be a hash containing:
  - A narrative key with the generated narrative string
  - An actions key with an array of ActionRecord to_h representations
  - A conversation key with the updated Conversation object (user message and new assistant message added)
- When no actions are detected, the actions array should be empty and the narrative should reflect that nothing specific happened (or provide a conversational response)
- When the workflow fails, result may be nil and error should contain the failure message

**Tests**:
- Test that successful workflow result contains all expected keys
- Test that narrative is a string
- Test that actions is an array of hashes with expected ActionRecord structure
- Test that conversation contains the updated conversation object
- Test that failed workflow has nil result and populated error

---

## Milestone 4 - Build Serializer and Refactor Controller

Create the response serializer and refactor the controller to its minimal form.

### 4.1 - Create ChatResponseSerializer

**Intent**: Create a serializer that transforms the workflow into the API response format. This provides a clear boundary between internal workflow state and the external API contract.

**Details**:
- Create at `app/serializers/chat_response_serializer.rb`
- The constructor accepts a workflow object (anything that responds to result, complete?, failed?, error)
- Provide a serialize method that returns a hash matching the existing API contract:
  - success - boolean, true if workflow is complete, false if failed
  - reply - string, the narrative text from the workflow result
  - conversation - hash, the serialized conversation from the workflow result (using conversation.to_h)
  - error - string or nil, the error message if the workflow failed
- When the workflow failed, reply should be a fallback message and error should contain the actual error
- Provide a serialize_json method that returns the serialized hash as a JSON string
- The serializer must maintain backward compatibility with the existing API response structure

**Tests**:
- Test that a successful workflow serializes with success true and narrative in reply
- Test that a failed workflow serializes with success false and error message
- Test that reply contains the narrative text from the result
- Test that conversation matches the expected structure
- Test that the output matches the existing API response contract exactly
- Test that serialize_json returns valid JSON

---

### 4.2 - Refactor DndChatController

**Intent**: Reduce the controller to minimal responsibilities. It should only receive the payload, delegate to the orchestrator, and serialize the response.

**Details**:
- Modify the create_message action to:
  1. Validate that the message parameter is present and not empty (keep existing validation)
  2. Load the current conversation from the file
  3. Add the user message to the conversation
  4. Create a new DndChatWorkflow instance
  5. Create a new WorkflowOrchestrator with the workflow
  6. Call process on the orchestrator, passing the user message as prompt, the conversation, and the sandbox path
  7. If the workflow completed successfully, add the assistant message (narrative) to the conversation and persist
  8. Create a ChatResponseSerializer with the workflow and return the serialized response
- Remove the following private methods as they are no longer needed:
  - parse_tool_payload (replaced by ActionDetectionPrompt)
  - normalize_tool_arguments (replaced by ActionDetectionPrompt)
  - render_reply_text (replaced by NarrativePrompt)
  - render_narrative (replaced by NarrativePrompt)
  - fallback_narrative (replaced by NarrativePrompt error handling)
- Keep the following unchanged:
  - Sandbox and tool loading before_actions
  - Contract endpoints (messages_contract, agent_contract, agent_version_contract)
  - SPA endpoint
  - Messages GET endpoint
  - Agent and agent_version endpoints
- Keep the helper methods for loading conversation, memory_store, inventory_store as they are still used by agent endpoints

**Tests**:
- Test that the controller delegates to the orchestrator
- Test that the controller uses the serializer for the response
- Test that the existing API contract is maintained (same response structure)
- Test that error responses still work correctly
- Test that the agent and agent_version endpoints are unchanged
- Test that the conversation is persisted with both user and assistant messages

---

## Milestone 5 - Integration and Cleanup

Final integration testing and documentation updates.

### 5.1 - End-to-End Integration Tests

**Intent**: Create comprehensive integration tests that verify the full workflow from HTTP request through all services to response. These tests use real LLM calls when credentials are available.

**Details**:
- Implemented at `test/integration/dnd_workflow_integration_test.rb`
- Skips when LLM credentials are unavailable (API_KEY and LLM_URL)
- Scenarios covered:
  - Simple single-action prompt
  - Multi-action prompt
  - Conversation continuity across multiple messages
  - Action memory population (via MemoryStore)
- Verification points:
  - Narrative present and response follows API contract
  - Actions captured in memory
  - Conversation persists user and assistant turns

**Tests**:
- Simple prompt completes the workflow
- Multi-action prompt processes actions
- Actions appear in memory after execution
- Conversation persists across turns

### 5.3 - Context Tools

**Intent**: Provide structured context for narration and targeted memory summaries.

**Details**:
- `CurrentContextTool`: returns current scene, people, current quest, and recent conversation for narration context.
- `ContextCompressionTool`: iterates all memory sections, uses each memory’s summarize/weight, and produces a weighted overall summary (used when narration context exceeds CONTEXT_TOKEN_MAX).
- `MemorySummarizeTool`: now targets specific items (person/location/quest_log) instead of broad dumps.

**Tests**:
- `test/tools/current_context_tool_test.rb`
- `test/tools/context_compression_tool_test.rb`
- Updated `test/tools/memory_summarize_tool_test.rb`

---

### 5.2 - Update Documentation

**Intent**: Update reference documentation to reflect the new architecture.

**Details**:
- Create the following new reference documents:
  - `docs/references/app/prompts/base_references.md` - index for prompts directory
  - `docs/references/app/prompts/base_prompt.md`
  - `docs/references/app/prompts/action_detection_prompt.md`
  - `docs/references/app/prompts/narrative_prompt.md`
  - `docs/references/app/prompts/outcome_prompt.md`
  - `docs/references/app/services/base_workflow.md`
  - `docs/references/app/services/workflow_orchestrator.md`
  - `docs/references/app/models/workflow_state.md`
  - `docs/references/app/models/action_record.md`
  - `docs/references/app/serializers/base_references.md` - index for serializers directory
  - `docs/references/app/serializers/chat_response_serializer.md`
- Update the following existing reference documents:
  - `docs/references/app/services/dnd_chat_workflow.md` - reflect new structure
  - `docs/references/app/controllers/dnd_chat_controller.md` - reflect slim responsibilities
  - `docs/references/base_references.md` - add new file tree entries
- Update `docs/references/architecture_diagram.md` to show the new flow:
  - Controller delegates to Orchestrator
  - Orchestrator calls Workflow (setup then execute)
  - Workflow uses Prompts for LLM interaction
  - Workflow uses ToolCallService for tool execution
  - Controller uses Serializer for response formatting

**Tests**:
- Verify all new reference documents exist
- Verify architecture diagram reflects the new flow
- Verify base_references.md includes all new entries
