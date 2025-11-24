require "test_helper"

class TranslationServiceTest < ActiveSupport::TestCase
  def setup
    @service = TranslationService.new(timeout: 60)
  end

  # Basic functionality tests (no LLM calls - safe for parallel execution)
  test "should parse JSON document correctly" do
    json_doc = '{"greeting": "Hola Mundo"}'
    parsed_doc = @service.parse_document(json_doc, "application/json")
    assert_equal "Hola Mundo", parsed_doc["greeting"]
  end

  test "should parse YAML document correctly" do
    yaml_doc = "greeting: Hola Mundo\nfarewell: Adiós"
    parsed_doc = @service.parse_document(yaml_doc, "application/x-yaml")
    assert_equal "Hola Mundo", parsed_doc["greeting"]
    assert_equal "Adiós", parsed_doc["farewell"]
  end

  test "should convert to YAML format correctly" do
    data = { "greeting" => "Hello" }
    yaml_data = @service.convert_to_yaml(data)
    assert_equal data, yaml_data
  end

  test "should handle string input conversion" do
    text = "Hello World"
    result = @service.convert_to_yaml(text)
    assert_equal "Hello World", result
  end

  test "should auto-detect JSON format when no hint provided" do
    json_doc = '{"test": "value"}'
    parsed_doc = @service.parse_document(json_doc, nil)
    assert_equal "value", parsed_doc["test"]
  end

  test "should fall back to YAML when JSON parsing fails" do
    yaml_doc = "test: value"
    parsed_doc = @service.parse_document(yaml_doc, nil)
    assert_equal "value", parsed_doc["test"]
  end

  test "should convert to JSON export format" do
    data = { "greeting" => "Hello" }
    result = @service.convert_to_export_format(data, "JSON")
    parsed_result = JSON.parse(result)
    assert_equal "Hello", parsed_result["greeting"]
  end

  test "should convert to YAML export format" do
    data = { "greeting" => "Hello" }
    result = @service.convert_to_export_format(data, "YAML")
    assert result.start_with?("---")
    parsed_result = YAML.safe_load(result)
    assert_equal "Hello", parsed_result["greeting"]
  end

  test "should validate export format" do
    assert_raises(ArgumentError) do
      @service.translate_document(
        doc_content: '{"test": "value"}',
        input_format: "application/json",
        export_format: "INVALID"
      )
    end
  end

  test "should propagate JSON parsing errors" do
    assert_raises(JSON::ParserError) do
      @service.parse_document("invalid json", "application/json")
    end
  end

  test "should propagate YAML parsing errors" do
    assert_raises(Psych::SyntaxError) do
      @service.parse_document("invalid: yaml: content:", "application/x-yaml")
    end
  end

  test "should initialize with custom LLM URL and timeout" do
    custom_service = TranslationService.new(
      llm_url: "http://custom-llm:8080",
      timeout: 120,
      protected_strings: [ "CustomTerm" ]
    )
    assert_not_nil custom_service
  end

  test "should handle empty string in translate_text method" do
    context = TranslationContext.new(text: "")
    result = @service.translate_text(context)
    assert_equal "", result

    context = TranslationContext.new(text: "   ")
    result = @service.translate_text(context)
    assert_equal "   ", result
  end

  # Language code conversion tests (no LLM calls)
  test "should convert language codes to names" do
    service_es = TranslationService.new(target_language: "es")
    service_en = TranslationService.new(target_language: "en")
    service_fr = TranslationService.new(target_language: "fr")

    # Check that the service initializes with correct target languages
    assert_equal "Spanish", service_es.instance_variable_get(:@target_language)
    assert_equal "English", service_en.instance_variable_get(:@target_language)
    assert_equal "French", service_fr.instance_variable_get(:@target_language)
  end

  test "should default to Spanish for unknown language codes" do
    service = TranslationService.new(target_language: "xyz")
    assert_equal "Spanish", service.instance_variable_get(:@target_language)
  end

  test "should handle language names as input" do
    service = TranslationService.new(target_language: "German")
    assert_equal "German", service.instance_variable_get(:@target_language)
  end

  # Integration tests with real LLM (well-written, naturally isolated)
  test "should translate English to Spanish by default" do
    json_doc = '{"message": "Good morning everyone"}'

    result = @service.translate_document(
      doc_content: json_doc,
      input_format: "application/json",
      export_format: "JSON"
    )

    parsed_result = JSON.parse(result)
    # Should be different from original (translated to Spanish)
    assert_not_equal "Good morning everyone", parsed_result["message"]
    assert_not_empty parsed_result["message"].strip
    # Should contain Spanish words
    assert_match(/buenos|días|mañana|todos/i, parsed_result["message"])
  end

  test "should translate English to French when specified" do
    json_doc = '{"greeting": "Good evening"}'

    result = @service.translate_document(
      doc_content: json_doc,
      input_format: "application/json",
      export_format: "JSON",
      target_language: "fr"
    )

    parsed_result = JSON.parse(result)
    assert_not_equal "Good evening", parsed_result["greeting"]
    assert_not_empty parsed_result["greeting"].strip
    # Should contain French words
    assert_match(/bonsoir|soir/i, parsed_result["greeting"])
  end

  test "should preserve simple injection variables" do
    json_doc = '{"message": "Hello {user_name}, welcome back"}'

    result = @service.translate_document(
      doc_content: json_doc,
      input_format: "application/json",
      export_format: "JSON",
      target_language: "es"
    )

    parsed_result = JSON.parse(result)
    # Should preserve the exact variable
    assert_includes parsed_result["message"], "{user_name}"
    # Should translate the rest
    assert_not_equal "Hello {user_name}, welcome back", parsed_result["message"]
  end

  test "should preserve multiple injection variables" do
    json_doc = '{"notification": "Your {student_name} completed {assignment_title}"}'

    result = @service.translate_document(
      doc_content: json_doc,
      input_format: "application/json",
      export_format: "JSON",
      target_language: "es"
    )

    parsed_result = JSON.parse(result)
    assert_includes parsed_result["notification"], "{student_name}"
    assert_includes parsed_result["notification"], "{assignment_title}"
    assert_not_equal "Your {student_name} completed {assignment_title}", parsed_result["notification"]
  end

  test "should preserve Brightwheel by default" do
    json_doc = '{"text": "Welcome to Brightwheel platform"}'

    result = @service.translate_document(
      doc_content: json_doc,
      input_format: "application/json",
      export_format: "JSON",
      target_language: "es"
    )

    parsed_result = JSON.parse(result)
    # Brightwheel should always be preserved
    assert_includes parsed_result["text"], "Brightwheel"
    # Rest should be translated
    assert_not_equal "Welcome to Brightwheel platform", parsed_result["text"]
  end

  test "should preserve custom protected strings" do
    protected_service = TranslationService.new(
      timeout: 60,
      protected_strings: [ "CustomApp", "SpecialTool" ],
      target_language: "es"
    )

    json_doc = '{"text": "Using CustomApp with SpecialTool for learning"}'

    result = protected_service.translate_document(
      doc_content: json_doc,
      input_format: "application/json",
      export_format: "JSON"
    )

    parsed_result = JSON.parse(result)
    assert_includes parsed_result["text"], "CustomApp"
    assert_includes parsed_result["text"], "SpecialTool"
    assert_not_equal "Using CustomApp with SpecialTool for learning", parsed_result["text"]
  end

  test "should handle injection variables and protected strings together" do
    protected_service = TranslationService.new(
      timeout: 60,
      protected_strings: [ "MyApp" ],
      target_language: "es"
    )

    json_doc = '{"message": "Hello {user_name}, welcome to MyApp"}'

    result = protected_service.translate_document(
      doc_content: json_doc,
      input_format: "application/json",
      export_format: "JSON"
    )

    parsed_result = JSON.parse(result)
    assert_includes parsed_result["message"], "{user_name}"
    assert_includes parsed_result["message"], "MyApp"
    assert_not_equal "Hello {user_name}, welcome to MyApp", parsed_result["message"]
  end

  test "should handle YAML documents" do
    yaml_doc = <<~YAML
      greeting: Good afternoon
      farewell: See you later
      nested:
        message: Have a great day
    YAML

    result = @service.translate_document(
      doc_content: yaml_doc,
      input_format: "application/x-yaml",
      export_format: "YAML",
      target_language: "es"
    )

    parsed_result = YAML.safe_load(result)
    assert_not_equal "Good afternoon", parsed_result["greeting"]
    assert_not_equal "See you later", parsed_result["farewell"]
    assert_not_equal "Have a great day", parsed_result["nested"]["message"]
  end

  test "should handle complex injection variables with underscores and numbers" do
    json_doc = '{"message": "Student {student_id_123} finished {assignment_v2} in {subject_area}"}'

    result = @service.translate_document(
      doc_content: json_doc,
      input_format: "application/json",
      export_format: "JSON",
      target_language: "es"
    )

    parsed_result = JSON.parse(result)
    assert_includes parsed_result["message"], "{student_id_123}"
    assert_includes parsed_result["message"], "{assignment_v2}"
    assert_includes parsed_result["message"], "{subject_area}"
  end

  test "should translate Spanish to English" do
    english_service = TranslationService.new(timeout: 60, target_language: "en")

    json_doc = '{"greeting": "Buenos días"}'

    result = english_service.translate_document(
      doc_content: json_doc,
      input_format: "application/json",
      export_format: "JSON"
    )

    parsed_result = JSON.parse(result)
    assert_not_equal "Buenos días", parsed_result["greeting"]
    assert_match(/good|morning|day/i, parsed_result["greeting"])
  end

  test "should translate French to English" do
    english_service = TranslationService.new(timeout: 60, target_language: "en")

    json_doc = '{"message": "Comment allez-vous"}'

    result = english_service.translate_document(
      doc_content: json_doc,
      input_format: "application/json",
      export_format: "JSON"
    )

    parsed_result = JSON.parse(result)
    assert_not_equal "Comment allez-vous", parsed_result["message"]
    assert_match(/how|are|you/i, parsed_result["message"])
  end

  test "should handle language codes es, en, fr correctly" do
    test_cases = [
      { code: "es", input: "Hello world", should_change: true },
      { code: "en", input: "Hola mundo", should_change: true },
      { code: "fr", input: "Hello world", should_change: true }
    ]

    test_cases.each do |test_case|
      json_doc = %Q({"text": "#{test_case[:input]}"})

      result = @service.translate_document(
        doc_content: json_doc,
        input_format: "application/json",
        export_format: "JSON",
        target_language: test_case[:code]
      )

      parsed_result = JSON.parse(result)
      if test_case[:should_change]
        assert_not_equal test_case[:input], parsed_result["text"], "Should translate when target is #{test_case[:code]}"
      end
      assert_not_empty parsed_result["text"].strip
    end
  end

  # Pluralization tests
  test "should handle i18n pluralization with nested structure" do
    json_doc = <<~JSON
      {
        "food": {
          "amount_one": "{{count}} ounce",
          "amount_other": "{{count}} ounces"
        }
      }
    JSON

    result = @service.translate_document(
      doc_content: json_doc,
      input_format: "application/json",
      export_format: "JSON",
      target_language: "es"
    )

    parsed_result = JSON.parse(result)
    
    # Should preserve {{count}} variable in both forms
    assert_includes parsed_result["food"]["amount_one"], "{{count}}"
    assert_includes parsed_result["food"]["amount_other"], "{{count}}"
    
    # Should translate the words but not the count variable
    assert_not_equal "{{count}} ounce", parsed_result["food"]["amount_one"]
    assert_not_equal "{{count}} ounces", parsed_result["food"]["amount_other"]
  end

  test "should handle i18n pluralization at root level" do
    json_doc = <<~JSON
      {
        "student_count_one": "{{count}} student",
        "student_count_other": "{{count}} students"
      }
    JSON

    result = @service.translate_document(
      doc_content: json_doc,
      input_format: "application/json",
      export_format: "JSON",
      target_language: "es"
    )

    parsed_result = JSON.parse(result)
    
    # Should preserve {{count}} variable in both forms
    assert_includes parsed_result["student_count_one"], "{{count}}"
    assert_includes parsed_result["student_count_other"], "{{count}}"
    
    # Should translate the words but not the count variable
    assert_not_equal "{{count}} student", parsed_result["student_count_one"]
    assert_not_equal "{{count}} students", parsed_result["student_count_other"]
  end

  test "should handle multiple pluralization patterns in same document" do
    json_doc = <<~JSON
      {
        "messages": {
          "item_count_one": "{{count}} item available",
          "item_count_other": "{{count}} items available"
        },
        "teacher_count_one": "{{count}} teacher",
        "teacher_count_other": "{{count}} teachers"
      }
    JSON

    result = @service.translate_document(
      doc_content: json_doc,
      input_format: "application/json",
      export_format: "JSON",
      target_language: "es"
    )

    parsed_result = JSON.parse(result)
    
    # Check nested pluralization
    assert_includes parsed_result["messages"]["item_count_one"], "{{count}}"
    assert_includes parsed_result["messages"]["item_count_other"], "{{count}}"
    
    # Check root level pluralization
    assert_includes parsed_result["teacher_count_one"], "{{count}}"
    assert_includes parsed_result["teacher_count_other"], "{{count}}"
  end
end
