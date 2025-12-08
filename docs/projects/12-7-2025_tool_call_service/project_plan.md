# Project Plan: Tool Calling Service

## Overview

Implement a tool calling service that supports three tools (read_file, write_file, bash) using an inheritance-based architecture. Each tool is a subclass of BaseTool with its own schema and execution logic. The service integrates with the existing LLM infrastructure for testing.

## Goals

- Create a BaseTool abstract class with common tool patterns
- Implement read_file, write_file, and bash tools as subclasses
- Build a ToolCallService to orchestrate tool lookup and execution
- Use a sandboxed `test/tool_test/` directory for safe file operation tests
- Validate tools work correctly with LLM integration

---

## Milestone 1 - Base Tool Infrastructure

Create the foundational tool architecture and orchestration service.

### 1.1 - Create BaseTool Abstract Class

**Intent**: Establish a base class that defines the common interface and patterns for all tools. This provides consistent schema generation and execution contracts.

**Details**:
- Create `app/tools/base_tool.rb` as a PORO
- Define class method `schema` returning OpenAI function calling format:
  - `type: "function"`
  - `function: { name:, description:, parameters: {} }`
- Define class method `name` returning the tool name string
- Define instance method `execute(**args)` that raises NotImplementedError
- Return structured result hash: `{ success: bool, result: string, error: string }`

**Tests**:
- Test `schema` returns hash with required OpenAI function structure
- Test `name` returns a string
- Test `execute` raises NotImplementedError on base class
- Test result structure includes success, result, and error keys

---

### 1.2 - Create ToolCallService

**Intent**: Build a service that registers available tools and dispatches execution requests. This centralizes tool management and provides a clean interface for the LLM integration.

**Details**:
- Create `app/services/tool_call_service.rb`
- Initialize with optional `sandbox_path` for restricting file operations
- Class method `available_tools` returns array of all tool schemas
- Instance method `execute(tool_name:, arguments:)` dispatches to appropriate tool
- Look up tool by name, instantiate with sandbox_path, call execute
- Raise `ArgumentError` for unknown tool names

**Tests**:
- Test `available_tools` returns array of tool schemas
- Test `execute` dispatches to correct tool class
- Test `execute` raises ArgumentError for unknown tool
- Test sandbox_path is passed to tool instances

---

## Milestone 2 - Read File Tool

Implement the read_file tool for reading file contents.

### 2.1 - Create ReadFileTool

**Intent**: Create a tool that reads file contents, with sandbox path validation to ensure safe file access during testing.

**Details**:
- Create `app/tools/read_file_tool.rb` extending BaseTool
- Schema: accepts `path` parameter (string, required)
- Description: "Read the contents of a file at the specified path"
- Validate path is within sandbox_path if sandbox is configured
- Read and return file contents on success
- Return error result for non-existent files or path violations

**Tests**:
- Test schema returns valid OpenAI function format with path parameter
- Test execute reads file content successfully
- Test execute returns error for non-existent file
- Test execute returns error when path escapes sandbox
- Test works with `test/tool_test/` sandbox directory
- Test cleanup removes test files after test run

---

## Milestone 3 - Write File Tool

Implement the write_file tool for creating and writing files.

### 3.1 - Create WriteFileTool

**Intent**: Create a tool that writes content to files, with automatic directory creation and sandbox validation.

**Details**:
- Create `app/tools/write_file_tool.rb` extending BaseTool
- Schema: accepts `path` and `content` parameters (strings, required)
- Description: "Write content to a file at the specified path"
- Validate path is within sandbox_path if sandbox is configured
- Create parent directories if they don't exist (FileUtils.mkdir_p)
- Write content to file and return success result
- Return error result for path violations or write failures

**Tests**:
- Test schema returns valid OpenAI function format with path and content parameters
- Test execute creates file with correct content
- Test execute creates nested directories as needed
- Test execute returns error when path escapes sandbox
- Test file content is correctly written and readable
- Test cleanup removes test files and directories after test run

---

## Milestone 4 - Bash Tool

Implement the bash tool for command execution with LLM integration testing.

### 4.1 - Create BashTool

**Intent**: Create a tool that executes bash commands and captures output. Use this tool to validate LLM integration by having the LLM request a file listing.

**Details**:
- Create `app/tools/bash_tool.rb` extending BaseTool
- Schema: accepts `command` parameter (string, required)
- Description: "Execute a bash command and return the output"
- Use `Open3.capture3` for command execution
- Capture stdout, stderr, and exit status
- Return structured result with stdout as result, stderr in error if failed
- Include exit_status in result metadata

**Tests**:
- Test schema returns valid OpenAI function format with command parameter
- Test execute runs command and returns stdout
- Test execute captures stderr on failure
- Test execute includes exit status
- Test with `ls` command on `test/tool_test/` directory
- Test LLM integration: prompt LLM to list files, verify it calls bash tool with ls
- Test cleanup of any files created during LLM integration test

