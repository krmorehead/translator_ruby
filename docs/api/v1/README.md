# API Documentation

This directory contains OpenAPI v3 specifications for the Translation Service API endpoints.

## Available Endpoints

### 1. Single Text Translation - `translate_text.yaml`

**Endpoint:** `POST /api/v1/translate_text`

Translate a single text string with full control over context, formality, and source language.

**Use cases:**
- Real-time UI translations
- Dynamic content translation
- Context-aware translations
- Formality control (formal vs. casual)

### 2. Document Translation - `translate.yaml`

**Endpoint:** `POST /api/v1/translate`

Translate entire documents (JSON or YAML) with support for nested structures and pluralization.

**Use cases:**
- Bulk translation of locale files
- i18n file translation
- Complex nested structures
- Pluralization patterns

## Viewing the Specifications

### Using Swagger UI

1. **Online:** Visit [Swagger Editor](https://editor.swagger.io/)
2. **Import:** Copy and paste the YAML content or upload the file
3. **Explore:** Interactive documentation with try-it-out features

### Using Redoc

```bash
npm install -g redoc-cli
redoc-cli serve translate_text.yaml
```

### Using VS Code

Install the "OpenAPI (Swagger) Editor" extension for syntax highlighting and validation.

## Testing the API

### Using cURL

```bash
# Single text translation
curl -X POST http://73.190.101.126:52020/api/v1/translate_text \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Hello world",
    "target_lang": "es"
  }'

# Document translation
curl -X POST http://73.190.101.126:52020/api/v1/translate \
  -d 'doc_to_translate={"greeting":"Hello"}&export_format=JSON&target_language=es'
```

### Using Postman

1. Import the OpenAPI specification into Postman
2. Postman will automatically create a collection with all endpoints
3. Update the base URL to your server
4. Test the endpoints

### Using Generated Clients

Generate client libraries using [OpenAPI Generator](https://openapi-generator.tech/):

```bash
# JavaScript/TypeScript client
openapi-generator-cli generate -i translate_text.yaml -g typescript-fetch -o clients/typescript

# Python client
openapi-generator-cli generate -i translate_text.yaml -g python -o clients/python

# Ruby client
openapi-generator-cli generate -i translate_text.yaml -g ruby -o clients/ruby
```

## Key Features

### Formality Levels (Enum)

Both endpoints support formality control:
- `formal` - Standard formal tone (default)
- `less` - Casual/informal tone
- `default` - Neutral tone
- `more` - Very formal tone
- `prefer_more` - Prefer formal but flexible
- `prefer_less` - Prefer casual but flexible

### Variable Preservation

The API automatically preserves template variables:
- Single braces: `{user_name}`, `{count}`
- Double braces: `{{count}}`, `{{variable}}`

### Translation Hash

For document translation, use `translation_hash: true` to provide custom context:

```json
{
  "custom_message": {
    "translation_hash": true,
    "text": "Welcome to our application",
    "context": "app.onboarding.welcome",
    "formality": "formal",
    "source_lang": "en"
  }
}
```

## Response Formats

### Success (200 OK)

**Single Text:**
```json
{
  "translation": "Hola mundo"
}
```

**Document:**
```json
{
  "greeting": "Hola mundo",
  "message": "Bienvenido"
}
```

### Error (400 Bad Request)

```json
{
  "error": "text is required"
}
```

### Error (500 Internal Server Error)

```json
{
  "error": "Translation failed",
  "details": "LLM service unavailable"
}
```

## Validation

The OpenAPI specs can be validated using:

```bash
# Using swagger-cli
swagger-cli validate translate_text.yaml

# Using openapi-generator
openapi-generator-cli validate -i translate_text.yaml
```

## Contributing

When updating the API:
1. Update the corresponding OpenAPI specification
2. Update the version number in `info.version`
3. Add examples for new parameters
4. Update this README if needed

## Support

For questions or issues, please contact the API support team.

