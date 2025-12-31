# Project Plan: Visual Diff System

## Overview

Create a comprehensive visual diff system for previewing and reviewing file changes, inspired by Cline's diff preview feature. This system shows users exactly what will change before execution (preview mode) and what changed after execution (review mode). This builds trust in agent actions and enables catching errors before they're committed.

## Goals

- Generate diffs for planned file changes before execution
- Display diffs in side-by-side or unified format
- Parse and highlight syntax in diff content
- Show file-level summaries (additions/deletions counts)
- Enable approval/rejection workflow (future: approval gates)
- Integrate with checkpoints for post-execution review
- Support multiple file formats and large diffs
- Make diffs readable and actionable

---

## Milestone 1 - Diff Generation and Parsing

Create services for generating preview diffs and parsing unified diff format.

### 1.1 - Create DiffPreviewService

**Intent**: Create a service that generates diffs for planned file changes before they're executed. This enables "preview before write" functionality.

**Details**:
- Create in app/services/diff_preview_service.rb
- Accept parameters: file_path, new_content, old_content (or nil for new files)
- Methods:
  - preview_change(file_path, new_content) → DiffPreview object
  - preview_multiple(changes_hash) → array of DiffPreview objects
  - generate_unified_diff(old_content, new_content, file_path) → string
- Read current file content if file exists (old_content)
- Use Ruby's built-in Diff library or shell out to git diff --no-index
- Handle new files (no old_content): show entire file as additions
- Handle deleted files: show entire file as deletions
- Generate unified diff format with context lines
- Return DiffPreview domain object with structured data
- Handle errors: file not readable, binary files

**Tests**:
- Test preview_change for modified file
- Test preview_change for new file
- Test preview_change for deleted file
- Test preview_multiple with multiple changes
- Test unified diff generation
- Test error handling for binary files
- Test error handling for unreadable files

---

### 1.2 - Create UnifiedDiffParser

**Intent**: Create a parser that converts unified diff format into structured objects for frontend consumption. This enables rich diff visualization.

**Details**:
- Create in app/services/unified_diff_parser.rb
- Accept unified diff string
- Parse into structured objects: file header, hunks, lines
- Extract file paths (old and new)
- Parse hunk headers (@@ -start,count +start,count @@)
- Parse lines: additions (+), deletions (-), context (space)
- Detect file operation: added, deleted, modified, renamed
- Handle edge cases: empty files, no newline at end of file
- Return DiffPreview object with array of DiffHunk objects
- Follow unified diff format specification
- Handle malformed diffs gracefully

**Tests**:
- Test parsing simple diff (few changes)
- Test parsing complex diff (multiple hunks)
- Test parsing new file diff
- Test parsing deleted file diff
- Test parsing renamed file diff
- Test hunk header parsing
- Test line classification (add/delete/context)
- Test malformed diff handling

---

### 1.3 - Create DiffPreview Class

**Intent**: Create a domain object representing a complete file diff with metadata and hunks. This provides detailed, line-by-line diff information for visual rendering.

**Details**:
- Implement as PORO in app/models/diff_preview.rb
- Required attributes: file_path, operation (:added, :modified, :deleted), hunks (array of DiffHunk)
- Optional attributes: old_path (for renames), old_content, new_content, is_binary
- Statistics: lines_added, lines_deleted, lines_unchanged
- Methods:
  - total_changes → lines_added + lines_deleted
  - change_summary → "+5 -3"
  - has_changes? → lines_added > 0 || lines_deleted > 0
  - file_extension → extracted from file_path
- Implement to_h for serialization (includes all hunks)
- Implement self.from_diff_string(diff_string) using UnifiedDiffParser
- Validate: file_path is string, hunks is array
- Follow OOP patterns
- **Note**: This class is distinct from `FileDiff` (created in Git Checkpoint System project, Step 2.3). `FileDiff` provides summary-level statistics (file path, change type, insertion/deletion counts) for checkpoint diffs. `DiffPreview` provides detailed hunk and line-by-line information with full diff content for visual rendering in the frontend. Both classes serve different granularity levels and use cases

**Tests**:
- Test initialization with valid parameters
- Test from_diff_string class method
- Test statistics calculation
- Test change_summary formatting
- Test file_extension extraction
- Test to_h serialization
- Test validation

---

## Milestone 2 - Diff Domain Models

Create detailed domain models for diff hunks and lines.

### 2.1 - Create DiffHunk Class

**Intent**: Create a domain object representing a single hunk (continuous block of changes) in a diff.

**Details**:
- Implement as PORO in app/models/diff_hunk.rb
- Required attributes: old_start, old_count, new_start, new_count, lines (array of DiffLine)
- Optional attributes: context (text after @@), header (full @@ line)
- Methods:
  - line_count → total lines in hunk
  - added_lines → array of DiffLine where type == :addition
  - deleted_lines → array of DiffLine where type == :deletion
  - context_lines → array of DiffLine where type == :context
- Implement to_h and self.from_header_and_lines
- Validate: start and count are integers, lines is array
- Follow OOP patterns

**Tests**:
- Test initialization with valid parameters
- Test from_header_and_lines parsing
- Test line_count calculation
- Test added_lines filtering
- Test deleted_lines filtering
- Test context_lines filtering
- Test to_h serialization
- Test validation

---

### 2.2 - Create DiffLine Class

**Intent**: Create a domain object representing a single line in a diff with its type and content.

**Details**:
- Implement as PORO in app/models/diff_line.rb
- Required attributes: type (:addition, :deletion, :context), content (string)
- Optional attributes: old_line_number, new_line_number
- Methods:
  - addition? → type == :addition
  - deletion? → type == :deletion
  - context? → type == :context
  - formatted_content → content with leading + or - stripped
- Implement to_h
- Implement self.from_diff_line(line_string) → parses "+content", "-content", " content"
- Validate: type is one of allowed symbols, content is string
- Follow OOP patterns

**Tests**:
- Test initialization with valid parameters
- Test from_diff_line parsing for addition
- Test from_diff_line parsing for deletion
- Test from_diff_line parsing for context
- Test type query methods (addition?, deletion?, context?)
- Test formatted_content strips prefix
- Test to_h serialization
- Test validation

---

### 2.3 - Create DiffsController

**Intent**: Create API endpoints for frontend to fetch diff previews and checkpoint diffs.

**Details**:
- Create app/controllers/api/v1/diffs_controller.rb
- Routes in config/routes.rb:
  - POST /api/v1/diffs/preview - generate preview diff for planned changes
  - GET /api/v1/diffs/checkpoint/:checkpoint_id - get diff for checkpoint
  - GET /api/v1/diffs/step/:step_id - get diff for executed step
- Methods: preview, checkpoint, step
- Accept parameters:
  - preview: { file_path:, new_content: }
  - checkpoint: checkpoint_id
  - step: step_id
- Use DiffPreviewService for preview generation
- Use GitDiffGenerator for checkpoint diffs
- Return JSON with DiffPreview serialization
- Handle errors: file not found, invalid checkpoint, unauthorized

**Tests**:
- Test POST /diffs/preview generates diff
- Test GET /diffs/checkpoint/:id returns checkpoint diff
- Test GET /diffs/step/:id returns step diff
- Test error handling for missing files
- Test error handling for invalid IDs
- Test JSON response format

---

## Milestone 3 - Frontend Diff Visualization

Create React components for displaying diffs in the frontend.

### 3.1 - Create DiffViewer Component

**Intent**: Create the main diff viewer component that displays file diffs in unified or side-by-side format.

**Details**:
- Create frontend/src/components/DiffViewer.jsx
- Props: diffData (DiffPreview object), format (:unified | :split), showLineNumbers (default true)
- Unified format: single column with +/- prefixes
- Split format: two columns (old | new) side-by-side
- Render file header: file path, operation, statistics
- Render each hunk with hunk header
- Render each line using DiffLine component
- Syntax highlighting for code (use Prism.js or highlight.js)
- Line numbers: old line number | new line number
- Collapsible hunks (expand/collapse)
- Search within diff
- Toggle format (unified ↔ split)
- Sticky file header on scroll

**Tests**:
- Test component renders with unified format
- Test component renders with split format
- Test file header display
- Test hunk rendering
- Test line number display
- Test syntax highlighting
- Test format toggle
- Test hunk collapse/expand

---

### 3.2 - Create DiffLine Component

**Intent**: Create a component for rendering individual diff lines with proper styling and highlighting.

**Details**:
- Create frontend/src/components/DiffLine.jsx
- Props: line (DiffLine object), showLineNumbers, language (for syntax highlighting)
- Style based on line type:
  - Addition: green background (#d4edda), green text
  - Deletion: red background (#f8d7da), red text
  - Context: white/gray background, normal text
- Line numbers: grayed out, monospace font
- Content: monospace font, preserve whitespace
- Syntax highlighting: apply language-specific highlighting to content
- Handle special characters (tabs, spaces) with visual indicators
- Support line selection for copying
- Hover effect for additions/deletions

**Tests**:
- Test component renders addition line
- Test component renders deletion line
- Test component renders context line
- Test line number display
- Test syntax highlighting application
- Test special character handling
- Test styling based on type

---

### 3.3 - Create FileChangesSummary Component

**Intent**: Create a summary component showing overview of all changed files with statistics.

**Details**:
- Create frontend/src/components/FileChangesSummary.jsx
- Props: diffs (array of DiffPreview objects)
- Display list of changed files with:
  - File path
  - Operation icon (A=added, M=modified, D=deleted)
  - Change statistics (+X -Y)
  - File type icon (based on extension)
- Click file to jump to its diff in viewer
- Filter controls: show only additions, only modifications, only deletions
- Sort options: by name, by changes (most changed first)
- Total statistics: X files changed, Y additions, Z deletions
- Collapse/expand all files
- Color coding: green for additions, red for deletions, blue for modifications

**Tests**:
- Test component renders file list
- Test operation icons display correctly
- Test statistics calculation
- Test filter controls
- Test sort options
- Test click to jump to file
- Test total statistics display

---

### 3.4 - Create useDiffData Hook

**Intent**: Create a custom React hook for fetching and managing diff data.

**Details**:
- Create frontend/src/hooks/useDiffData.js
- Functions:
  - useDiffPreview(filePath, newContent) → fetches preview diff
  - useCheckpointDiff(checkpointId) → fetches checkpoint diff
  - useStepDiff(stepId) → fetches step execution diff
- Manage loading state, error state, diff data
- Cache results to avoid redundant API calls
- Return: { diff, isLoading, error, refresh }
- Handle errors gracefully
- Support manual refresh

**Tests**:
- Test useDiffPreview fetches preview
- Test useCheckpointDiff fetches checkpoint diff
- Test useStepDiff fetches step diff
- Test loading state management
- Test error handling
- Test caching behavior
- Test refresh functionality

---

### 3.5 - Create Diff Highlighting Utility

**Intent**: Create utility functions for applying syntax highlighting to diff content.

**Details**:
- Create frontend/src/utils/diffHighlighting.js
- Functions:
  - highlightCode(content, language) → HTML with syntax highlighting
  - detectLanguage(filePath) → language string
  - applyDiffHighlighting(hunk, language) → highlighted hunk
- Use Prism.js or highlight.js for syntax highlighting
- Support common languages: JavaScript, Ruby, Python, HTML, CSS, JSON
- Preserve diff markers (+/-) in highlighted output
- Handle code that spans multiple lines in a hunk
- Escape HTML in content before highlighting
- Fallback to plain text for unsupported languages

**Tests**:
- Test highlightCode with JavaScript
- Test highlightCode with Ruby
- Test detectLanguage from file extension
- Test applyDiffHighlighting preserves diff markers
- Test fallback for unsupported languages
- Test HTML escaping

---

## Milestone 4 - Integration and Workflows

Integrate diff system with existing workflows and add approval gates.

### 4.1 - Integrate with WriteFileTool

**Intent**: Update WriteFileTool to generate preview diffs before writing files.

**Details**:
- Update app/tools/write_file_tool.rb
- Add optional dry_run parameter
- If dry_run: generate preview diff but don't write file
- Store preview diff in tool result
- Return preview diff to workflow for potential display/approval
- If not dry_run: write file as normal
- Keep existing validation and error handling

**Tests**:
- Test write_file with dry_run generates preview
- Test write_file without dry_run writes file
- Test preview diff is included in result
- Test file not written in dry_run mode

---

### 4.2 - Integrate with StepExecutionWorkflow

**Intent**: Update StepExecutionWorkflow to generate preview diffs before execution for review.

**Details**:
- Update app/workflows/step_execution_workflow.rb
- Before executing tool calls, run dry_run versions
- Generate preview diffs for all file changes
- Store diffs in workflow memory
- (Future: pause for user approval if approval_required flag set)
- Log diff summaries to help with debugging
- Proceed with actual execution after preview

**Tests**:
- Test workflow generates preview diffs
- Test diffs stored in memory
- Test execution proceeds after preview
- Test diff summaries logged

---

### 4.3 - Add Diff Review UI to AgentInspector

**Intent**: Integrate diff viewer into AgentInspector for reviewing executed changes.

**Details**:
- Update frontend/src/components/AgentInspector.jsx
- Add "Changes" tab showing FileChangesSummary
- Display diffs for most recent step execution
- Allow viewing diffs for any previous step
- Show preview diffs for pending steps (if available)
- Add approve/reject buttons (future: approval workflow)
- Link to checkpoint diffs for milestone boundaries
- Responsive layout

**Tests**:
- Test AgentInspector renders Changes tab
- Test diff viewer displays correctly
- Test navigation between step diffs
- Test approve/reject buttons (UI only, no backend yet)
- Test responsive layout

---

## Milestone 5 - Advanced Features and Polish

Add advanced diff features and polish.

### 5.1 - Word-Level Diff Highlighting

**Intent**: Add word-level (character-level) diff highlighting within changed lines for better precision.

**Details**:
- When a line is modified (deleted + added), compare old and new versions
- Highlight specific words/characters that changed
- Use different background color for word-level changes (darker shade)
- Algorithm: use diff library at character level within line
- Apply to both unified and split views
- Make word-level highlighting optional (toggle)

**Tests**:
- Test word-level highlighting identifies changes
- Test highlighting applies correct styling
- Test toggle enables/disables feature
- Test works in both unified and split views

---

### 5.2 - Diff Commenting (Future Feature)

**Intent**: Enable users to add comments on specific lines in diffs for review and feedback.

**Details**:
- Add comment button on each diff line
- Store comments associated with: file_path, line_number, checkpoint_id
- Display comments inline in diff viewer
- Allow replying to comments (thread)
- Mark comments as resolved
- Backend: create Comment model and API endpoints
- Frontend: add comment UI components

**Tests**:
- Test comment creation on diff line
- Test comment display inline
- Test comment threads
- Test marking resolved
- Test comment persistence

---

### 5.3 - Diff Export and Sharing

**Intent**: Enable exporting diffs for sharing and documentation.

**Details**:
- Add export button to DiffViewer
- Export formats:
  - Unified diff (.patch file)
  - HTML (styled diff for viewing in browser)
  - PDF (formatted diff for printing)
  - GitHub-style diff (markdown-compatible)
- Generate filename with checkpoint ID or step ID
- Include metadata: timestamp, file names, statistics
- Support copying diff to clipboard

**Tests**:
- Test export to .patch file
- Test export to HTML
- Test export to PDF
- Test clipboard copy
- Test filename generation

---

## Milestone 6 - Testing and Documentation

Complete with comprehensive testing and documentation.

### 6.1 - Integration Testing

**Intent**: Create end-to-end tests for diff system.

**Details**:
- Create test/integration/diff_system_integration_test.rb
- Test scenarios:
  1. Generate preview diff for file change
  2. Execute change and review diff via API
  3. Frontend displays diff correctly
  4. Compare checkpoint diffs
  5. Large diff handling (1000+ line files)
- Use ActAgentWorker with file modifications
- Verify API responses match expected format
- Verify frontend components render diffs

**Tests**:
- Integration test: preview diff generation
- Integration test: checkpoint diff retrieval
- Integration test: frontend diff display
- Integration test: large diff handling
- Integration test: binary file handling

---

### 6.2 - Performance Optimization

**Intent**: Ensure diff system performs well with large files and many changes.

**Details**:
- Optimize diff generation: use efficient diff algorithms
- Lazy load diff content: only load visible hunks
- Virtual scrolling for large diffs (1000+ lines)
- Cache parsed diffs to avoid re-parsing
- Compress diff data for API responses
- Stream large diffs instead of loading all at once
- Monitor and log performance metrics

**Tests**:
- Performance test: large file diff (10k+ lines)
- Performance test: many file diffs (50+ files)
- Performance test: rendering time
- Measure API response times
- Verify optimizations improve performance

---

### 6.3 - Documentation

**Intent**: Document the diff system for developers and users.

**Details**:
- Create docs/references/diff_system.md
- Document: architecture, diff generation, parsing, visualization
- Explain diff format (unified diff specification)
- Provide usage examples: generating previews, viewing diffs
- Document API endpoints
- Document frontend components and props
- Include diagrams: diff flow, component hierarchy
- Document syntax highlighting languages supported
- Provide troubleshooting guide

**Tests**:
- Manual review of documentation completeness
- Verify all examples are accurate
- Check API documentation matches implementation

---

## Execution Guidelines

1. Implement backend (Milestones 1-2) before frontend (Milestone 3)
2. Test with real file changes (use WriteFileTool)
3. Test with various file types (Ruby, JavaScript, JSON, markdown)
4. Write tests for both Rails and React components
5. Keep diff viewer performance in mind (large files)
6. Use established diff formats (unified diff)
7. Run full test suite after each step
8. Commit after each milestone
9. Update file_references.md as files are created

## Success Criteria

- [ ] Preview diffs generated for planned changes
- [ ] Checkpoint diffs retrieved and displayed
- [ ] Diff viewer renders unified and split formats
- [ ] Syntax highlighting works for common languages
- [ ] File changes summary shows statistics
- [ ] API endpoints return correct diff data
- [ ] All tests pass with >85% coverage
- [ ] Integrated into AgentInspector
- [ ] Performance acceptable with large diffs
- [ ] Documentation complete and accurate

## Design Guidelines

**Visual Principles:**
- Use GitHub diff styling as inspiration (familiar to developers)
- Green for additions (+), red for deletions (-), gray for context
- Monospace font for code content
- Clear line numbers on both sides
- Good contrast for accessibility
- Syntax highlighting that doesn't interfere with diff colors
- Scrollable with sticky headers

**UX Principles:**
- Make it easy to scan changes quickly (statistics, file list)
- Support both detailed review (line-by-line) and quick overview
- Provide controls (format toggle, collapse/expand)
- Handle errors gracefully (binary files, large files)
- Load quickly (lazy load large diffs)
- Enable keyboard navigation
- Support copying content

