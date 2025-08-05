require "test_helper"

class TranslationServiceTest < ActiveSupport::TestCase
  def setup
    # Use the real LLM endpoint for testing actual translation functionality
    @service = TranslationService.new(timeout: 60)
  end

  test "should parse JSON document correctly" do
    json_doc = '{"greeting": "Hola Mundo"}'

    # Test the parsing without actually calling LLM
    parsed_doc = @service.send(:parse_document, json_doc, "application/json")
    assert_equal "Hola Mundo", parsed_doc["greeting"]
  end

  test "should parse YAML document correctly" do
    yaml_doc = "greeting: Hola Mundo\nfarewell: Adiós"

    parsed_doc = @service.send(:parse_document, yaml_doc, "application/x-yaml")
    assert_equal "Hola Mundo", parsed_doc["greeting"]
    assert_equal "Adiós", parsed_doc["farewell"]
  end

  test "should convert to YAML format correctly" do
    data = { "greeting" => "Hello" }
    yaml_data = @service.send(:convert_to_yaml, data)
    assert_equal data, yaml_data
  end

  test "should handle string input conversion" do
    text = "Hello World"
    result = @service.send(:convert_to_yaml, text)
    # String input that doesn't parse as YAML becomes a plain string, not wrapped in text key
    assert_equal "Hello World", result
  end

  test "should auto-detect JSON format when no hint provided" do
    json_doc = '{"test": "value"}'
    parsed_doc = @service.send(:parse_document, json_doc, nil)
    assert_equal "value", parsed_doc["test"]
  end

  test "should fall back to YAML when JSON parsing fails" do
    yaml_doc = "test: value"
    parsed_doc = @service.send(:parse_document, yaml_doc, nil)
    assert_equal "value", parsed_doc["test"]
  end

  test "should convert to JSON export format" do
    data = { "greeting" => "Hello" }
    result = @service.send(:convert_to_export_format, data, "JSON")

    parsed_result = JSON.parse(result)
    assert_equal "Hello", parsed_result["greeting"]
  end

  test "should convert to YAML export format" do
    data = { "greeting" => "Hello" }
    result = @service.send(:convert_to_export_format, data, "YAML")

    assert result.start_with?("---")
    parsed_result = YAML.safe_load(result)
    assert_equal "Hello", parsed_result["greeting"]
  end

  test "should validate export format" do
    json_doc = '{"test": "value"}'

    error = assert_raises(ArgumentError) do
      @service.translate_document(
        doc_content: json_doc,
        input_format: "application/json",
        export_format: "XML"
      )
    end

    assert_match(/export_format must be JSON or YAML/, error.message)
  end

  test "should propagate JSON parsing errors" do
    invalid_json = '{"invalid": json}'

    assert_raises(JSON::ParserError) do
      @service.translate_document(
        doc_content: invalid_json,
        input_format: "application/json",
        export_format: "JSON"
      )
    end
  end

  test "should propagate YAML parsing errors" do
    invalid_yaml = "invalid:\n  yaml:\n content"

    assert_raises(Psych::SyntaxError) do
      @service.translate_document(
        doc_content: invalid_yaml,
        input_format: "application/x-yaml",
        export_format: "YAML"
      )
    end
  end

  test "should initialize with custom LLM URL and timeout" do
    custom_service = TranslationService.new(llm_url: "http://custom:8080", timeout: 60)

    assert_equal "http://custom:8080", custom_service.instance_variable_get(:@llm_url)
    assert_equal 60, custom_service.instance_variable_get(:@timeout)
  end

  test "should translate simple text using real LLM" do
    result = @service.send(:translate_text, "Hola")
    assert_not_equal "Hola", result, "Translation should change the text"
    assert_not_empty result.strip, "Translation should not be empty"
  end

  test "should translate Spanish text to English" do
    spanish_text = "Buenos días, ¿cómo está usted?"
    result = @service.send(:translate_text, spanish_text)

    assert_not_equal spanish_text, result, "Translation should change the original text"
    assert_not_empty result.strip, "Translation should not be empty"
    # The result should be in English - we can check for common English words
    assert_match(/good|morning|how|are|you/i, result, "Translation should contain English words")
  end

  test "should translate French text to English" do
    french_text = "Bonjour, comment allez-vous?"
    result = @service.send(:translate_text, french_text)

    assert_not_equal french_text, result, "Translation should change the original text"
    assert_not_empty result.strip, "Translation should not be empty"
  end

  test "should translate complete JSON document" do
    json_doc = '{"greeting": "Hola", "farewell": "Adiós"}'

    result = @service.translate_document(
      doc_content: json_doc,
      input_format: "application/json",
      export_format: "JSON"
    )

    parsed_result = JSON.parse(result)
    assert_not_equal "Hola", parsed_result["greeting"], "Greeting should be translated"
    assert_not_equal "Adiós", parsed_result["farewell"], "Farewell should be translated"
  end

  test "should translate complete YAML document" do
    yaml_doc = "greeting: Bonjour\nfarewell: Au revoir"

    result = @service.translate_document(
      doc_content: yaml_doc,
      input_format: "application/x-yaml",
      export_format: "YAML"
    )

    parsed_result = YAML.safe_load(result)
    assert_not_equal "Bonjour", parsed_result["greeting"], "Greeting should be translated"
    assert_not_equal "Au revoir", parsed_result["farewell"], "Farewell should be translated"
  end

  test "should handle empty string in translate_text method" do
    result = @service.send(:translate_text, "")
    assert_equal "", result

    result = @service.send(:translate_text, "   ")
    assert_equal "   ", result
  end

  test "should preserve injection variables during translation" do
    text_with_variables = "{school_name} has shared a new form with you"
    result = @service.send(:translate_text, text_with_variables)
    
    # Should preserve the injection variable
    assert_includes result, "{school_name}", "Injection variable should be preserved"
    # Should not be the same as original (translation should occur for other parts)
    assert_not_equal text_with_variables, result, "Text should be translated except for injection variables"
  end

  test "should preserve multiple injection variables" do
    text_with_variables = "Hello {user_name}, welcome to {school_name}"
    result = @service.send(:translate_text, text_with_variables)
    
    assert_includes result, "{user_name}", "First injection variable should be preserved"
    assert_includes result, "{school_name}", "Second injection variable should be preserved"
  end

  test "should preserve protected strings during translation" do
    # Test with default protected string "Brightwheel"
    text_with_protected = "Welcome to Brightwheel, your educational platform"
    result = @service.send(:translate_text, text_with_protected)
    
    assert_includes result, "Brightwheel", "Protected string 'Brightwheel' should be preserved"
  end

  test "should preserve custom protected strings" do
    service_with_protected = TranslationService.new(protected_strings: ["CustomApp", "SpecialTerm"])
    text_with_protected = "CustomApp is the best SpecialTerm for learning"
    result = service_with_protected.send(:translate_text, text_with_protected)
    
    assert_includes result, "CustomApp", "Custom protected string 'CustomApp' should be preserved"
    assert_includes result, "SpecialTerm", "Custom protected string 'SpecialTerm' should be preserved"
  end

  test "should handle both injection variables and protected strings together" do
    service_with_protected = TranslationService.new(protected_strings: ["MyApp"])
    text_mixed = "Hello {user_name}, welcome to MyApp"
    result = service_with_protected.send(:translate_text, text_mixed)
    
    assert_includes result, "{user_name}", "Injection variable should be preserved"
    assert_includes result, "MyApp", "Protected string should be preserved"
    assert_not_equal text_mixed, result, "Text should be translated except for protected elements"
  end

  test "should translate to specified target language" do
    json_doc = '{"message": "Hello world", "greeting": "Good morning"}'
    
    result = @service.translate_document(
      doc_content: json_doc,
      input_format: "application/json",
      export_format: "JSON",
      target_language: "French"
    )
    
    parsed_result = JSON.parse(result)
    assert_not_equal "Hello world", parsed_result["message"], "Message should be translated"
    assert_not_equal "Good morning", parsed_result["greeting"], "Greeting should be translated"
  end

  test "should handle injection variables in document translation" do
    json_doc = '{"message": "{school_name} has shared a new assignment", "title": "Notification from {app_name}"}'
    
    result = @service.translate_document(
      doc_content: json_doc,
      input_format: "application/json",
      export_format: "JSON",
      target_language: "Spanish"
    )
    
    parsed_result = JSON.parse(result)
    assert_includes parsed_result["message"], "{school_name}", "Injection variable in message should be preserved"
    assert_includes parsed_result["title"], "{app_name}", "Injection variable in title should be preserved"
  end

  test "should handle protected strings in document translation with custom protected strings" do
    yaml_doc = "welcome: Welcome to CustomSchool\napp_name: Using MySpecialApp"
    
    result = @service.translate_document(
      doc_content: yaml_doc,
      input_format: "application/x-yaml",
      export_format: "YAML",
      protected_strings: ["CustomSchool", "MySpecialApp"],
      target_language: "Spanish"
    )
    
    parsed_result = YAML.safe_load(result)
    assert_includes parsed_result["welcome"], "CustomSchool", "Protected string 'CustomSchool' should be preserved"
    assert_includes parsed_result["app_name"], "MySpecialApp", "Protected string 'MySpecialApp' should be preserved"
  end

  test "should preserve Brightwheel by default in any context" do
    text = "Brightwheel is an educational platform"
    result = @service.send(:translate_text, text)
    
    assert_includes result, "Brightwheel", "Brightwheel should always be preserved"
    assert_not_equal text, result, "Text should be translated except for Brightwheel"
  end

  test "should handle complex injection variables with underscores and numbers" do
    text = "Your {student_name_1} has completed {assignment_2} in {subject_area}"
    result = @service.send(:translate_text, text)
    
    assert_includes result, "{student_name_1}", "Complex injection variable should be preserved"
    assert_includes result, "{assignment_2}", "Numbered injection variable should be preserved"
    assert_includes result, "{subject_area}", "Underscore injection variable should be preserved"
  end

  test "should handle edge case with empty injection variables" do
    text = "Hello {} and {user_name}"
    result = @service.send(:translate_text, text)
    
    assert_includes result, "{}", "Empty braces should be preserved"
    assert_includes result, "{user_name}", "Valid injection variable should be preserved"
  end

  test "should default target language to Spanish" do
    json_doc = '{"message": "Hello world"}'
    
    # Don't specify target_language, should default to Spanish
    result = @service.translate_document(
      doc_content: json_doc,
      input_format: "application/json",
      export_format: "JSON"
    )
    
    parsed_result = JSON.parse(result)
    assert_not_equal "Hello world", parsed_result["message"], "Should translate to default Spanish"
  end
end
