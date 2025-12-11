# Project Plan: HTML Menu Parsing API

## Overview

Create a new v1 API endpoint that accepts HTML documents representing restaurant/institutional menus and extracts structured menu data using LLM-powered parsing. The system supports dynamic resolution levels (multiple parsing passes with increasing detail), optional HTML preprocessing to clean and structure raw HTML, and returns clean JSON output without external service references.

## Goals

- Provide a REST API endpoint for parsing HTML menus into structured JSON
- Support configurable resolution levels for iterative refinement
- Implement optional HTML preprocessing to improve LLM extraction accuracy
- Follow existing architectural patterns (Controllers → Services → Prompts)
- Maintain test coverage and documentation standards
- Return menu data conforming to CACFP component structure

---

## Milestone 1 - Request Layer Foundation

Build the API request layer including controller, context objects, and routing.

### 1.1 - Create MenuParserController

**Intent**: Create the HTTP interface for menu parsing requests. This controller validates input parameters, coordinates with the service layer, and returns properly formatted responses. Follows the established pattern from TranslationController.

**Details**:
- Create `app/controllers/api/v1/menu_parser_controller.rb`
- Inherits from `ApplicationController`
- Primary action: `parse` - accepts HTML and returns structured menu JSON
- Secondary action: `contract` - returns an OpenAPI 3.1 snippet describing the full API contract (request + response) for `POST /api/v1/parse_menu`, including params, formats, errors, and the final-pass response schema
- Accept parameters:
  - `html_content` (required) - raw HTML string of the menu
  - `resolution` (optional, default: 5) - number of parsing passes (1-5)
  - `preprocess` (optional, default: true) - enable HTML preprocessing
  - `preprocessing_options` (optional) - hash of preprocessing configuration
- Validate required parameters and return 400 for missing data
- Return 422 for invalid resolution values (must be 1-5)
- Catch service errors and return appropriate HTTP status codes
- Return JSON response with proper content-type headers
- Log errors using Rails.logger for debugging

**Tests**:
- Test successful parsing with minimal parameters
- Test error response for missing html_content
- Test error response for invalid resolution value (0, 6, negative)
- Test default resolution value (5) when not specified
- Test preprocess parameter defaults to true
- Test preprocessing_options are properly passed through
- Test error handling for service exceptions
- Test response format and content-type header
- Test request validation and parameter sanitization
- Test `GET /api/v1/parse_menu/contract` returns the OpenAPI snippet with 200
- Test contract includes request schema (body params, headers), success response schema, and error responses
- Test contract matches the final-pass response contract fields/enums in OpenAPI schema
- Test contract endpoint is read-only and requires no params

---

### 1.2 - Create MenuPreprocessingConfig

**Intent**: Create a configuration object to specify HTML preprocessing options. This encapsulates all the preprocessing settings in a single, validated object that can be easily tested and extended.

**Details**:
- Create `app/models/menu_preprocessing_config.rb`
- Implemented as Plain Old Ruby Object
- Attributes with defaults:
  - `strip_styles` (Boolean, default: true) - remove style tags and attributes
  - `strip_scripts` (Boolean, default: true) - remove script tags
  - `strip_classes` (Boolean, default: true) - remove class attributes
  - `strip_ids` (Boolean, default: true) - remove id attributes
  - `normalize_structure` (Boolean, default: true) - flatten unnecessary nesting
  - `extract_semantic_tree` (Boolean, default: false) - convert to semantic tree format
  - `extract_text_only` (Boolean, default: false) - extract visible text with structure
  - `simplify_to_json` (Boolean, default: false) - pre-convert to simplified JSON
- Use keyword arguments for initialization
- Provide class method `default` that returns sensible defaults
- Provide class method `aggressive` for maximum preprocessing
- Provide class method `minimal` for light preprocessing only
- Include validation to ensure boolean types

**Tests**:
- Test default configuration values
- Test initialization with custom values
- Test `default` class method returns correct defaults
- Test `aggressive` preset enables all preprocessing
- Test `minimal` preset uses light preprocessing
- Test all attributes are properly set
- Test boolean type validation
- Test configuration can be serialized to hash
- Test configuration can be created from hash
- Test immutability of preset configurations

---

### 1.3 - Add Routes

**Intent**: Register the new menu parsing endpoint in the Rails routing configuration following the established v1 API pattern.

**Details**:
- Update `config/routes.rb`
- Add within `api/v1` namespace:
  - `POST /api/v1/parse_menu` → `menu_parser#parse`
  - `GET /api/v1/parse_menu/contract` → `menu_parser#contract` (serves OpenAPI schema snippet)
- Follow existing naming conventions for v1 routes
- Ensure route is properly scoped under api/v1 namespace

**Tests**:
- Test route resolves to correct controller and action
- Test POST request is routed correctly
- Test route accepts required parameters
- Test route returns 404 for incorrect HTTP methods (GET, PUT, DELETE)
- Test route is accessible under /api/v1 namespace

---

### 1.4 - Prepare Sample Fixtures Early

**Intent**: Make real HTML and reference JSON fixtures available upfront so all later unit, service, prompt, and integration tests can reuse them without duplication.

**Details**:
- Create `test/fixtures/sample_menus/` directory
- Copy provided artifacts from `docs/projects/12-11-2025_menu_parsing_api/`:
  - `weekly_school_menu.html` (real-world styled menu)
  - `weekly_school_menu_html_focused.html` (semantic/structured menu)
  - `ducling-html+bedrock-claude.json` (expected-shape reference output)
- Add a short README in the fixtures folder explaining each file and its source path
- Ensure fixtures are encoded as UTF-8 and safe for Nokogiri parsing
- Reference these fixtures in upcoming controller, service, prompt, serializer, and integration tests

**Tests**:
- Verify fixtures are readable in test suite (File.exist? and UTF-8)
- Verify Nokogiri can parse both HTML fixtures without errors
- Verify JSON reference loads and matches expected keys (`parsed_data.weeks`, etc.)
- Verify paths are correctly referenced in planned tests (controller/service/integration)
- Verify README accurately describes fixture origins and usage

---

## Milestone 2 - LLM Integration and Response Handling

Implement the LLM prompt for menu extraction and define how the raw LLM output is returned with minimal wrapping (no serializer).

### 2.1 - Create MenuExtractionPrompt

**Intent**: Implement the LLM prompt that extracts structured menu data from HTML (or preprocessed HTML). Supports dynamic resolution levels where subsequent passes build upon previous results with greater detail.

**Details**:
- Create `app/prompts/menu_extraction_prompt.rb`
- Inherits from `BasePrompt`
- Initialization accepts:
  - `resolution_level` (Integer) - current parsing detail level (1-5)
  - `previous_result` (Hash, optional) - result from previous pass
  - `preprocessing_applied` (Boolean) - whether HTML was preprocessed
  - `current_pass` (Integer) - which pass in multi-resolution (for context)
- Override `system_prompt` to provide menu extraction instructions:
  - Identify menu structure (weeks, days, meals)
  - Enforce explicit weekly schema aligned to `ducling-html+bedrock-claude.json`:
    - `weeks` array with sequential `weekNumber` (start at 1), ordered by appearance
    - `days` ordered as presented; ensure recognized day names (Mon–Sun) with fallback handling
    - `meals` grouped under each day with mealType normalization (Breakfast, Lunch, Snack, PM Snack, Dinner)
    - Support week/day-level `notes`
  - Extract food items with CACFP categories
  - Recognize meal types (Breakfast, Lunch, Snack, PM Snack, Dinner)
  - Categorize foods: grain, fruit, vegetable, milk, meat_alt
  - Map to CACFP components: Grain, Fruit, Vegetable, Milk, Meat/Meat Alternate
  - Mark all items as custom (isCustom: true, matchedFoodItemId: null)
  - Extract notes if present
  - Handle multiple weeks if present
- Dynamic resolution instructions:
  - Resolution 1: Extract basic structure and obvious items
  - Resolution 2+: Build upon previous result, add more detail, fill gaps
  - Higher resolution: Focus on completeness, edge cases, implicit items
- Override `model` to use appropriate LLM (GPT-4o or Claude for structured output)
- Override `response_schema` to define strict output structure:
  - Root object with `weeks` array
  - Week object: `weekNumber`, `days` array, `notes`
  - Day object: `dayOfWeek`, `meals` array, `notes`
  - Meal object: `name`, `mealType`, `foodItems` array
  - FoodItem: `name`, `category`, `matchedFoodItemId`, `cacfpComponent`, `isCustom`
- Include examples in system prompt for few-shot learning
- Handle preprocessed input differently (tree/text/JSON vs raw HTML)
- Align schema with final-pass response contract (see MenuParsingService) and ensure prompts instruct the LLM to populate all required fields for `parsed_data` and omit external references

**Tests**:
- Test system prompt includes menu extraction instructions
- Test system prompt includes CACFP categories
- Test weekly structure enforcement: sequential weekNumber, ordered weeks/days as in sample HTML, notes support
- Test prompt against `weekly_school_menu.html` and `weekly_school_menu_html_focused.html` fixtures for both raw and preprocessed modes
- Test system prompt adapts to resolution level
- Test system prompt includes previous result for multi-pass
- Test system prompt mentions preprocessing when applied
- Test response schema matches required output structure
- Test response schema aligns with final-pass contract (required fields, enums, null handling)
- Test response schema is strict and validates correctly
- Test model selection returns appropriate LLM
- Test prompt execution with simple HTML
- Test prompt execution with complex multi-week menu
- Test multi-resolution flow improves detail
- Test handling of preprocessed tree format
- Test handling of preprocessed text format
- Test handling of raw HTML
- Test extraction of all meal types
- Test food categorization accuracy
- Test CACFP component mapping

---

### 2.2 - Return LLM Output with Metadata (No Serializer)

**Intent**: Return the LLM’s validated output directly, attaching minimal metadata (resolution, preprocessing flags, passes, model, timestamp) without additional server-side restructuring.

**Details**:
- No serializer class; controller/service should forward the LLM JSON (already validated against the response schema)
- Attach `parsing_info` and `timestamp` alongside the LLM payload; avoid mutating `parsed_data`
- Ensure `response_schema` in MenuExtractionPrompt enforces the final-pass contract (weeks/days/meals/foodItems with required enums/fields)
- Keep output free of external references (no S3/Bedrock fields)
- Preserve ordering from the LLM output (weeks, days, meals)
- If optional metadata is omitted, still return the raw LLM `parsed_data`
- Contract format:
  - Serve OpenAPI 3.1 schema from `menu_parser#contract`
  - Schema describes full API contract: request body/params, headers, success response, and error responses
  - Response schema matches final-pass contract fields/enums (weeks/days/meals/foodItems, parsing_info, timestamp)

**Tests**:
- Test response body equals LLM payload plus minimal metadata (no restructuring)
- Test metadata fields are present: resolution, preprocessing, passes, model, timestamp
- Test no additional server-side transformations occur (deep equality to LLM parsed_data)
- Test response respects ordering from the fixture-aligned LLM output
- Test that invalid or missing schema fields are caught at the prompt/schema layer, not via post-processing

---

## Milestone 3 - Service Layer Implementation

Build the core business logic for menu parsing and HTML preprocessing.

### 3.1 - Create MenuParsingService

**Intent**: Implement the orchestration service that coordinates multi-resolution parsing, manages the iterative refinement process, and integrates with the HTML preprocessing and LLM prompt layers.

**Details**:
- Prerequisite: MenuExtractionPrompt (Milestone 3) must be implemented first so the service can delegate all LLM work.
- Create `app/services/menu_parsing_service.rb`
- Initialization accepts:
  - `timeout` (Integer, default: 60) - longer than translation due to menu complexity
  - (No direct LLM model/url config here; prompt layer owns model selection)
- Primary method: `parse_menu(menu_parsing_context)`
  - Returns structured menu hash conforming to output schema
  - Coordinates multi-resolution flow if resolution > 1
  - Integrates preprocessing if enabled
  - Calls MenuExtractionPrompt for LLM parsing
- Multi-resolution algorithm (within MenuExtractionPrompt):
  1. First pass: parse with standard detail level
  2. Subsequent passes: use previous result as context, request higher detail
  3. Each pass includes instruction to build upon previous result
  4. Final pass returns complete structured output
- Weekly structure (align to `ducling-html+bedrock-claude.json` reference):
  - `weeks` is an ordered array; `weekNumber` starts at 1 and increments sequentially
  - Preserve week ordering as they appear in source HTML
  - Within each week, preserve `days` ordering as presented (typically Mon–Fri)
  - Allow optional `notes` at week and day levels
- Final-pass response contract (must be enforced before serialization):
  - Root:
    - `parsed_data` (object, required)
    - `parsing_info` (object, required)
    - `timestamp` (string, ISO8601, required)
  - `parsed_data` object:
    - `weeks` (array, required; length ≥ 1)
    - `title` (string, optional)
    - `dateRange` (string or null, optional)
    - `notes` (string or null, optional)
    - Week object:
      - `weekNumber` (integer, required; sequential starting at 1)
      - `days` (array, required; preserve input order)
      - `notes` (string or null, optional)
    - Day object:
      - `dayOfWeek` (string, required; normalized weekday name)
      - `meals` (array, required; preserve input order)
      - `notes` (string or null, optional)
    - Meal object:
      - `name` (string, required)
      - `mealType` (enum: Breakfast, Lunch, Snack, PM Snack, Dinner; required)
      - `foodItems` (array, required)
    - FoodItem object:
      - `name` (string, required)
      - `category` (enum: grain, fruit, vegetable, milk, meat_alt; required)
      - `cacfpComponent` (enum: Grain, Fruit, Vegetable, Milk, Meat/Meat Alternate; required)
      - `matchedFoodItemId` (null, required for now)
      - `isCustom` (boolean, required; true)
  - `parsing_info` object:
    - `resolution` (integer, required)
    - `preprocessing` (boolean, required)
    - `passes` (integer, required)
    - `model` (string, required)
- Preprocessing integration:
  - If `preprocess` is true, call HtmlPreprocessingService before first parse
  - Pass preprocessed HTML to LLM instead of raw HTML
  - Include preprocessing metadata in context
- Error handling:
  - Catch LLM errors and wrap with descriptive messages
  - Log each resolution pass for debugging
  - Timeout protection for long-running parses
- Return structure matches example output:
  - `weeks` array with `weekNumber`, `days`, `meals`
  - `days` with `dayOfWeek`, `meals`, `notes`
  - `meals` with `name`, `mealType`, `foodItems`
  - `foodItems` with `name`, `category`, `cacfpComponent`, `isCustom`

**Tests**:
- Test single-pass parsing (resolution: 1)
- Test multi-pass parsing (resolution: 2)
- Test multi-pass parsing (resolution: 3)
- Test multi-pass parsing (resolution: 4)
- Test multi-pass parsing (resolution: 5)
- Test preprocessing integration enabled
- Test preprocessing integration disabled
- Test multi-week flow using `weekly_school_menu_html_focused.html` fixture to verify week/day ordering
- Test previous_result is passed to subsequent passes
- Test final output structure matches schema
- Test error handling for LLM failures
- Test error handling for timeout
- Test error handling for invalid HTML
- Test logging of each resolution pass
- Test integration with MenuExtractionPrompt
- Test multi-resolution improves detail level
- Test output includes all required fields
- Test fixture-to-contract alignment using `ducling-html+bedrock-claude.json` as reference for required fields/enums
- Test weekly structure matches reference: sequential weekNumber, ordered weeks/days, week/day notes handling

---

### 3.2 - Create HtmlPreprocessingService

**Intent**: Implement the HTML cleaning and structuring service that transforms raw, noisy HTML into cleaner representations optimized for LLM extraction. This significantly improves parsing accuracy by removing visual noise.

**Details**:
- Create `app/services/html_preprocessing_service.rb`
- Uses Nokogiri gem for HTML parsing and manipulation
- Primary method: `preprocess(html_content, config)`
  - `html_content` (String) - raw HTML
  - `config` (MenuPreprocessingConfig) - preprocessing settings
  - Returns processed HTML or structured representation
- Preprocessing operations (applied based on config):
  1. **Strip styles**: Remove `<style>` tags and `style` attributes
  2. **Strip scripts**: Remove `<script>` tags completely
  3. **Strip classes**: Remove `class` attributes from all elements
  4. **Strip ids**: Remove `id` attributes from all elements
  5. **Normalize structure**: Flatten unnecessary nested `<div>` wrappers
  6. **Extract semantic tree**: Convert DOM to indented text tree showing hierarchy
  7. **Extract text only**: Get visible text with minimal structure markers
  8. **Simplify to JSON**: Convert to preliminary JSON structure with sections/items
- Tree extraction format:
  ```
  table
    tbody
      tr "Breakfast"
        td "Monday"
        td "Raisin Bran, Orange, Milk"
  ```
- Text-only format:
  ```
  Breakfast
  Monday: Raisin Bran, Orange, Milk
  ```
- JSON simplification attempts to extract obvious sections/items structure
- Preserve semantic HTML tags (h1-h6, table, ul, li, p) as they indicate structure
- Each operation is independently toggleable via config
- Return preprocessed result with metadata about what was done

**Tests**:
- Test stripping style tags and attributes
- Test stripping script tags
- Test stripping class attributes
- Test stripping id attributes
- Test structure normalization removes nested divs
- Test semantic tree extraction format
- Test text-only extraction includes hierarchy
- Test JSON simplification extracts basic structure
- Test combination of multiple preprocessing options
- Test no preprocessing when all flags are false
- Test preservation of semantic HTML tags
- Test handling of malformed HTML
- Test handling of empty HTML
- Test metadata returned describes preprocessing applied
- Test each preprocessing operation is independent

---

## Milestone 3 - LLM Integration and Response Handling

Implement the LLM prompt for menu extraction and define how the raw LLM output is returned with minimal wrapping (no serializer).

### 3.1 - Create MenuExtractionPrompt

**Intent**: Implement the LLM prompt that extracts structured menu data from HTML (or preprocessed HTML). Supports dynamic resolution levels where subsequent passes build upon previous results with greater detail.

**Details**:
- Create `app/prompts/menu_extraction_prompt.rb`
- Inherits from `BasePrompt`
- Initialization accepts:
  - `resolution_level` (Integer) - current parsing detail level (1-5)
  - `previous_result` (Hash, optional) - result from previous pass
  - `preprocessing_applied` (Boolean) - whether HTML was preprocessed
  - `current_pass` (Integer) - which pass in multi-resolution (for context)
- Override `system_prompt` to provide menu extraction instructions:
  - Identify menu structure (weeks, days, meals)
  - Enforce explicit weekly schema aligned to `ducling-html+bedrock-claude.json`:
    - `weeks` array with sequential `weekNumber` (start at 1), ordered by appearance
    - `days` ordered as presented; ensure recognized day names (Mon–Sun) with fallback handling
    - `meals` grouped under each day with mealType normalization (Breakfast, Lunch, Snack, PM Snack, Dinner)
    - Support week/day-level `notes`
  - Extract food items with CACFP categories
  - Recognize meal types (Breakfast, Lunch, Snack, PM Snack, Dinner)
  - Categorize foods: grain, fruit, vegetable, milk, meat_alt
  - Map to CACFP components: Grain, Fruit, Vegetable, Milk, Meat/Meat Alternate
  - Mark all items as custom (isCustom: true, matchedFoodItemId: null)
  - Extract notes if present
  - Handle multiple weeks if present
- Dynamic resolution instructions:
  - Resolution 1: Extract basic structure and obvious items
  - Resolution 2+: Build upon previous result, add more detail, fill gaps
  - Higher resolution: Focus on completeness, edge cases, implicit items
- Override `model` to use appropriate LLM (GPT-4o or Claude for structured output)
- Override `response_schema` to define strict output structure:
  - Root object with `weeks` array
  - Week object: `weekNumber`, `days` array, `notes`
  - Day object: `dayOfWeek`, `meals` array, `notes`
  - Meal object: `name`, `mealType`, `foodItems` array
  - FoodItem: `name`, `category`, `matchedFoodItemId`, `cacfpComponent`, `isCustom`
- Include examples in system prompt for few-shot learning
- Handle preprocessed input differently (tree/text/JSON vs raw HTML)
- Align schema with final-pass response contract (see MenuParsingService) and ensure prompts instruct the LLM to populate all required fields for `parsed_data` and omit external references

**Tests**:
- Test system prompt includes menu extraction instructions
- Test system prompt includes CACFP categories
- Test weekly structure enforcement: sequential weekNumber, ordered weeks/days as in sample HTML, notes support
- Test prompt against `weekly_school_menu.html` and `weekly_school_menu_html_focused.html` fixtures for both raw and preprocessed modes
- Test system prompt adapts to resolution level
- Test system prompt includes previous result for multi-pass
- Test system prompt mentions preprocessing when applied
- Test response schema matches required output structure
- Test response schema aligns with final-pass contract (required fields, enums, null handling)
- Test response schema is strict and validates correctly
- Test model selection returns appropriate LLM
- Test prompt execution with simple HTML
- Test prompt execution with complex multi-week menu
- Test multi-resolution flow improves detail
- Test handling of preprocessed tree format
- Test handling of preprocessed text format
- Test handling of raw HTML
- Test extraction of all meal types
- Test food categorization accuracy
- Test CACFP component mapping

---

### 3.2 - Return LLM Output with Metadata (No Serializer)

**Intent**: Return the LLM’s validated output directly, attaching minimal metadata (resolution, preprocessing flags, passes, model, timestamp) without additional server-side restructuring.

**Details**:
- No serializer class; controller/service should forward the LLM JSON (already validated against the response schema)
- Attach `parsing_info` and `timestamp` alongside the LLM payload; avoid mutating `parsed_data`
- Ensure `response_schema` in MenuExtractionPrompt enforces the final-pass contract (weeks/days/meals/foodItems with required enums/fields)
- Keep output free of external references (no S3/Bedrock fields)
- Preserve ordering from the LLM output (weeks, days, meals)
- If optional metadata is omitted, still return the raw LLM `parsed_data`

**Tests**:
- Test response body equals LLM payload plus minimal metadata (no restructuring)
- Test metadata fields are present: resolution, preprocessing, passes, model, timestamp
- Test no additional server-side transformations occur (deep equality to LLM parsed_data)
- Test response respects ordering from the fixture-aligned LLM output
- Test that invalid or missing schema fields are caught at the prompt/schema layer, not via post-processing

## Milestone 4 - Integration and Documentation

Complete end-to-end testing, integration tests, and comprehensive documentation.

### 4.1 - Create Integration Tests

**Intent**: Verify the complete menu parsing flow works end-to-end with real HTML inputs, testing the integration of all components from controller through service to LLM and back.

**Details**:
- Create `test/integration/menu_parsing_flow_test.rb`
- Use real HTML examples (simple and complex menus) from `docs/projects/12-11-2025_menu_parsing_api/weekly_school_menu.html` and `weekly_school_menu_html_focused.html` (copied into `test/fixtures/sample_menus/`)
- Use `docs/projects/12-11-2025_menu_parsing_api/ducling-html+bedrock-claude.json` as an expected-shape reference for parsed output
- Test complete flows:
  1. Simple single-week menu without preprocessing
  2. Multi-week menu with preprocessing enabled
  3. High-resolution multi-pass parsing
  4. Various preprocessing configurations
- Verify complete response structure
- Verify food categorization accuracy
- Verify CACFP component mapping
- Test error scenarios:
  - Malformed HTML
  - Empty HTML
  - HTML with no menu structure
- Test performance (parsing should complete within reasonable time)
- Verify no external service references in output
- Test different meal types are recognized
- Test notes extraction when present

**Tests**:
- Test simple menu parsing end-to-end
- Test complex multi-week menu parsing
- Test with preprocessing disabled (raw HTML)
- Test with preprocessing enabled (various configs)
- Test multi-resolution parsing (resolution: 3)
- Test complete response structure validation
- Test food items are properly categorized
- Test CACFP components are correctly mapped
- Test all meal types are recognized (Breakfast, Lunch, Snack, PM Snack)
- Test notes are extracted when present
- Test error handling for malformed HTML
- Test error handling for empty content
- Test error handling for non-menu HTML
- Test parsing completes within timeout (< 90s for complex menus)
- Test output contains no S3/Bedrock references
- Test preprocessing improves parsing accuracy
- Test multi-resolution improves completeness

---

### 4.2 - Create Documentation

**Intent**: Document all new components following the established documentation pattern, ensuring future developers can understand the menu parsing system architecture and usage.

**Details**:
- Create documentation files in `docs/references/app/`:
  - `controllers/api/v1/menu_parser_controller.md`
  - `models/menu_parsing_context.md`
  - `models/menu_preprocessing_config.md`
  - `services/menu_parsing_service.md`
  - `services/html_preprocessing_service.md`
  - `prompts/menu_extraction_prompt.md`
  - `serializers/menu_response_serializer.md`
- Each doc should include:
  - File path reference
  - Purpose statement
  - Initialization/usage examples
  - Public method documentation with parameters and return values
  - Integration points with other components
  - Related files references
- Follow existing documentation format from translation components
- Update `docs/references/base_references.md` to include new files
- Update `docs/references/architecture_diagram.md` to show menu parsing flow
- Add menu parsing example to architecture diagram
- Document preprocessing options and their effects
- Document multi-resolution algorithm
- Document output schema with examples

**Tests**:
- Verify all new files are listed in base_references.md
- Verify documentation files exist for all new components
- Verify architecture diagram includes menu parsing flow
- Verify documentation follows established format
- Verify examples in documentation are accurate
- Verify cross-references between docs are correct
- Verify API endpoint is documented with curl examples

---

## Milestone 5 - Validation Polish

Finalize validation quality and error messaging.

### 5.1 - Add Validation and Error Messages

**Intent**: Improve error messages and validation to make the API more user-friendly and easier to debug.

**Details**:
- Enhance validation in MenuParsingContext:
  - Provide specific error messages for each validation failure
  - Suggest corrections (e.g., "resolution must be between 1 and 5, got: 6")
- Add HTML content validation in HtmlPreprocessingService:
  - Detect if content is actually HTML (has tags)
  - Detect if HTML is valid/parseable
  - Provide helpful errors for common issues
- Enhance MenuParsingService error handling:
  - Distinguish between parsing errors, LLM errors, timeout errors
  - Provide context about which resolution pass failed
  - Include partial results if later passes fail
- Add response validation in MenuResponseSerializer:
  - Validate required fields are present
  - Validate data types match schema
  - Provide warnings for unexpected structure
- Return 422 Unprocessable Entity with detailed errors for validation failures
- Log detailed error information for debugging

**Tests**:
- Test validation error messages are descriptive
- Test validation suggests corrections
- Test HTML validation detects non-HTML content
- Test HTML validation detects malformed HTML
- Test error responses include helpful context
- Test partial results returned if later pass fails
- Test 422 status for validation failures
- Test error logging includes full context
- Test response validation catches schema violations

## Execution Notes

### Dependencies

- Nokogiri gem for HTML parsing (likely already in Gemfile)
- Verify OpenAI gem supports structured output for menu extraction

### Environment Variables

- `LLM_URL` - LLM backend endpoint (existing)
- `LLM_MODEL` - Model for menu extraction (existing)

### Performance Considerations

- Menu parsing is more complex than simple translation
- Expect 10-30s for single resolution, 30-90s for multi-resolution
- Preprocessing adds 1-5s overhead but improves accuracy

### Test Fixtures Usage

- Use the provided sample assets across all testing layers:
  - `weekly_school_menu.html` and `weekly_school_menu_html_focused.html` for controller, service, and integration coverage
  - `ducling-html+bedrock-claude.json` as an expected-shape reference for serializer and end-to-end assertions
- Keep fixtures in `test/fixtures/sample_menus/` and refresh from `docs/projects/12-11-2025_menu_parsing_api/` if updated

### Future Enhancements

Not in scope for this project but worth noting:

- Batch menu parsing (multiple HTML files in one request)
- Streaming responses for long-running parses
- Custom food item matching against database
- Menu validation against CACFP requirements
- Menu diff/comparison for updated versions
- Support for PDF/image menu inputs (OCR preprocessing)

