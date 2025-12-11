# HTML Menu Parsing API

## Project Overview

This project adds a new v1 API endpoint to parse HTML documents representing restaurant/institutional menus into structured JSON output. The system uses LLM-powered extraction with support for:

- **Multi-resolution parsing**: Run multiple passes with increasing detail
- **HTML preprocessing**: Clean and structure raw HTML before LLM extraction
- **CACFP compliance**: Output matches CACFP component categories
- **Caching support**: Optional result caching for performance

## Key Features

### Dynamic Resolution
The API supports resolution levels 1-5, where higher resolution means more parsing passes:
- Resolution 1: Single pass, extracts basic structure
- Resolution 2+: Multiple passes, each building on previous results with greater detail

### Optional Preprocessing
Raw HTML often contains visual noise that confuses LLMs. The preprocessing service can:
- Strip styles, scripts, classes, and IDs
- Normalize nested structure
- Extract semantic tree representation
- Convert to simplified JSON/text format

This dramatically improves extraction accuracy.

### Structured Output
Consistent JSON output matching the CACFP menu structure:
```json
{
  "parsed_data": {
    "weeks": [
      {
        "weekNumber": 1,
        "days": [
          {
            "dayOfWeek": "Monday",
            "meals": [
              {
                "name": "Raisin Bran, Orange, Milk",
                "mealType": "Breakfast",
                "foodItems": [
                  {
                    "name": "Raisin Bran",
                    "category": "grain",
                    "cacfpComponent": "Grain",
                    "isCustom": true,
                    "matchedFoodItemId": null
                  }
                ]
              }
            ]
          }
        ]
      }
    ]
  },
  "parsing_info": {
    "resolution": 3,
    "preprocessing": true,
    "passes": 3
  },
  "timestamp": "2025-12-11T10:30:00Z"
}
```

## API Endpoint

```
POST /api/v1/parse_menu
```

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `html_content` | String | Yes | - | Raw HTML of the menu |
| `resolution` | Integer | No | 1 | Number of parsing passes (1-5) |
| `preprocess` | Boolean | No | false | Enable HTML preprocessing |
| `preprocessing_options` | Hash | No | - | Preprocessing configuration |

### Example Request

```bash
curl -X POST http://localhost:52020/api/v1/parse_menu \
  -H "Content-Type: application/json" \
  -d '{
    "html_content": "<html><body><h2>Week 1</h2>...</body></html>",
    "resolution": 3,
    "preprocess": true,
    "preprocessing_options": {
      "strip_styles": true,
      "extract_semantic_tree": true
    }
  }'
```

## Architecture

### Request Flow
```
Client Request
    ↓
MenuParserController (validates parameters)
    ↓
MenuParsingContext (data transfer object)
    ↓
MenuParsingService (orchestrates parsing)
    ↓
HtmlPreprocessingService (optional, cleans HTML)
    ↓
MenuExtractionPrompt (LLM extraction)
    ↓
MenuResponseSerializer (formats response)
    ↓
JSON Response
```

### Key Components

- **MenuParserController**: HTTP interface, parameter validation
- **MenuParsingContext**: Request data encapsulation
- **MenuPreprocessingConfig**: Preprocessing settings
- **MenuParsingService**: Multi-resolution orchestration
- **HtmlPreprocessingService**: HTML cleaning and structuring
- **MenuExtractionPrompt**: LLM prompt for extraction
- **MenuResponseSerializer**: Response formatting

## Implementation Plan

The project is organized into 5 milestones:

1. **Request Layer Foundation** - Controller, context objects, routing
2. **Service Layer Implementation** - Core parsing and preprocessing logic
3. **LLM Integration and Response Formatting** - Prompt and serializer
4. **Integration and Documentation** - E2E tests and docs
5. **Optimization and Polish** - Caching, validation, samples

See [project_plan.md](./project_plan.md) for detailed implementation steps.

## Testing Strategy

- Unit tests for each component (controllers, models, services, prompts)
- Integration tests for complete parsing flows
- Real HTML samples with expected outputs
- No mocking of LLM calls (per project standards)
- Performance validation (parsing within acceptable timeframes)

## Files Overview

- [project_plan.md](./project_plan.md) - Detailed implementation plan
- [file_references.md](./file_references.md) - All files involved in project
- [weekly_school_menu.html](./weekly_school_menu.html) - Real-world styled menu (fixture source)
- [weekly_school_menu_html_focused.html](./weekly_school_menu_html_focused.html) - Structured/semantic menu (fixture source)
- [ducling-html+bedrock-claude.json](./ducling-html+bedrock-claude.json) - Expected output shape reference

## Documentation

All new components will be documented following the established pattern:
- Purpose and responsibilities
- Initialization and usage examples
- Public method documentation
- Integration points
- Related files

Documentation will be added to `docs/references/app/` with proper indexing in `base_references.md`.

## Performance Considerations

- Single resolution parse: 10-30 seconds
- Multi-resolution parse: 30-90 seconds
- Preprocessing overhead: 1-5 seconds
- Caching enabled: Near-instant for repeated requests

## Future Enhancements

Not in current scope but potential additions:
- Batch menu parsing (multiple files)
- Streaming responses for long parses
- Custom food item database matching
- CACFP compliance validation
- Menu versioning and diff comparison
- PDF/image input support (with OCR)

