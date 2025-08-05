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
end
