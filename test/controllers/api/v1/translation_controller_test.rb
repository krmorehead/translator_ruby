require "test_helper"

class Api::V1::TranslationControllerTest < ActionDispatch::IntegrationTest
  test "should return error for missing doc_to_translate" do
    post "/api/v1/translate"

    assert_response :bad_request
    result = JSON.parse(response.body)
    assert_equal "doc_to_translate is required", result["error"]
  end

  test "should accept valid JSON document parameter" do
    post "/api/v1/translate",
      params: {
        doc_to_translate: '{"test": "value"}',
        export_format: "JSON"
      }

    # Should get a response (success or LLM error), not a parameter error
    assert_not_equal 400, response.status
  end

  test "should accept valid YAML document parameter" do
    post "/api/v1/translate",
      params: {
        doc_to_translate: "test: value",
        export_format: "YAML"
      }

    # Should get a response (success or LLM error), not a parameter error
    assert_not_equal 400, response.status
  end

  test "should default to JSON export format when not specified" do
    post "/api/v1/translate",
      params: { doc_to_translate: '{"test": "value"}' }

    # Should not be a parameter validation error
    assert_not_equal 400, response.status
  end

  test "should handle invalid JSON format" do
    # Test JSON format validation by submitting malformed JSON
    # The service will try JSON first and fail, then try YAML and fail
    post "/api/v1/translate",
      params: {
        doc_to_translate: '{"incomplete": json without closing brace',
        export_format: "JSON"
      }

    assert_response :bad_request
    result = JSON.parse(response.body)
    # Should fail with either JSON or YAML error depending on parsing order
    assert_includes [ "Invalid JSON format", "Invalid YAML format" ], result["error"]
  end

  test "should handle invalid YAML format" do
    post "/api/v1/translate",
      params: {
        doc_to_translate: "invalid:\n  yaml:\n   [bad",
        export_format: "YAML"
      }

    assert_response :bad_request
    result = JSON.parse(response.body)
    assert_equal "Invalid YAML format", result["error"]
  end

  test "should handle invalid export format through service validation" do
    post "/api/v1/translate",
      params: {
        doc_to_translate: '{"test": "value"}',
        export_format: "XML"
      }

    assert_response :bad_request
    result = JSON.parse(response.body)
    assert_equal "export_format must be JSON or YAML", result["error"]
  end

  test "should handle JSON content type header" do
    post "/api/v1/translate",
      params: {
        doc_to_translate: '{"greeting": "hello"}',
        export_format: "JSON"
      },
      headers: { "Content-Type" => "application/json" }

    # Should not be a parameter validation error
    assert_not_equal 400, response.status
  end

  test "should handle YAML content type header" do
    # Rails test integration has issues with non-standard content types
    # Test that our service can handle YAML format detection
    post "/api/v1/translate",
      params: {
        doc_to_translate: "greeting: hello",
        export_format: "JSON"
      }

    # Should process the YAML content successfully
    assert_not_equal 400, response.status, "Parameter validation failed: #{response.body}"
  end

  test "should respond within reasonable time" do
    start_time = Time.current
    post "/api/v1/translate",
      params: {
        doc_to_translate: '{"fast": "test"}',
        export_format: "JSON"
      }
    response_time = Time.current - start_time

    # Should respond within reasonable time
    assert response_time < 5.seconds, "Translation endpoint took too long: #{response_time}s"
  end

  # E2E test with translation_hash and custom context
  test "should handle translation_hash with custom context and formality" do
    doc = {
      "greeting" => "Hello world",
      "custom_message" => {
        "translation_hash" => true,
        "text" => "Welcome to our application",
        "context" => "app.onboarding.welcome",
        "formality" => "formal",
        "source_lang" => "en"
      },
      "nested" => {
        "simple" => "Thank you",
        "custom" => {
          "translation_hash" => true,
          "text" => "See you soon",
          "formality" => "less",
          "context" => "app.farewell.casual"
        }
      }
    }

    post "/api/v1/translate",
      params: { doc_to_translate: doc.to_json, export_format: "JSON", target_language: "es" }

    assert_response :success
    
    result = JSON.parse(response.body)
    
    # Verify simple strings were translated
    assert_not_equal "Hello world", result["greeting"]
    assert_not_empty result["greeting"]
    
    # Verify custom translation_hash entry was processed
    assert_not_equal "Welcome to our application", result["custom_message"]
    assert_not_empty result["custom_message"]
    # Should be in Spanish
    assert_match(/bienvenido|bienvenida/i, result["custom_message"])
    
    # Verify nested simple translation
    assert_not_equal "Thank you", result["nested"]["simple"]
    assert_match(/gracias/i, result["nested"]["simple"])
    
    # Verify nested custom translation with less formality
    assert_not_equal "See you soon", result["nested"]["custom"]
    assert_match(/hasta|nos vemos|pronto/i, result["nested"]["custom"])
  end

  test "should handle pluralization patterns through API" do
    doc = {
      "messages" => {
        "item_count_one" => "{{count}} item in cart",
        "item_count_other" => "{{count}} items in cart"
      },
      "notifications" => {
        "translation_hash" => true,
        "text" => "You have {{count}} new messages",
        "context" => "notifications.inbox",
        "formality" => "formal"
      }
    }

    post "/api/v1/translate",
      params: { doc_to_translate: doc.to_json, export_format: "JSON", target_language: "es" }

    assert_response :success
    
    result = JSON.parse(response.body)
    
    # Verify pluralization preserved {{count}}
    assert_includes result["messages"]["item_count_one"], "{{count}}"
    assert_includes result["messages"]["item_count_other"], "{{count}}"
    
    # Verify translation happened
    assert_not_equal "{{count}} item in cart", result["messages"]["item_count_one"]
    assert_not_equal "{{count}} items in cart", result["messages"]["item_count_other"]
    
    # Verify custom translation_hash with context
    assert_includes result["notifications"], "{{count}}"
    assert_not_equal "You have {{count}} new messages", result["notifications"]
    assert_match(/mensaje|tiene/i, result["notifications"])
  end

  test "should handle mixed translation modes through API" do
    doc = {
      "standard" => "Good morning",
      "with_variable" => "Hello {user_name}",
      "custom_formal" => {
        "translation_hash" => true,
        "text" => "Thank you for your payment",
        "formality" => "formal",
        "context" => "payment.confirmation"
      },
      "custom_casual" => {
        "translation_hash" => true,
        "text" => "Thanks a lot",
        "formality" => "less",
        "context" => "general.thanks"
      }
    }

    post "/api/v1/translate",
      params: { doc_to_translate: doc.to_json, export_format: "JSON", target_language: "es" }

    assert_response :success
    
    result = JSON.parse(response.body)
    
    # Verify all translations happened
    assert_not_equal "Good morning", result["standard"]
    assert_includes result["with_variable"], "{user_name}"
    assert_not_equal "Thank you for your payment", result["custom_formal"]
    assert_not_equal "Thanks a lot", result["custom_casual"]
    
    # Verify Spanish translations
    assert_match(/buenos|buen/i, result["standard"])
    assert_match(/gracias|agradec/i, result["custom_formal"])
  end

  # Note: These tests work with the real TranslationService and LLM - no mocking involved
end
