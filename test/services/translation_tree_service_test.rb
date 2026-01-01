require "test_helper"

class TranslationTreeServiceTest < ActiveSupport::TestCase
  def setup
    @service = TranslationTreeService.new(
      target_language: "Spanish",
      protected_strings: [ "Brightwheel" ]
    )

    # Real translation callback that uppercases text (no mocking)
    @translate_callback = ->(context) { context.text.upcase }
  end

  # Test simple string leaves
  speed_profile :fast
  test "should handle simple string leaf" do
    input = "hello"
    result = @service.traverse(input, @translate_callback)

    assert_equal "HELLO", result
  end

  speed_profile :fast
  test "should handle string leaf with context path" do
    input = "world"
    result = @service.traverse(input, @translate_callback, [ "greeting", "message" ])

    assert_equal "WORLD", result
  end

  # Test hash traversal
  speed_profile :fast
  test "should traverse hash with string leaves" do
    input = {
      greeting: "hello",
      farewell: "goodbye"
    }

    result = @service.traverse(input, @translate_callback)

    assert_equal "HELLO", result[:greeting]
    assert_equal "GOODBYE", result[:farewell]
  end

  speed_profile :fast
  test "should traverse nested hash structure" do
    input = {
      messages: {
        welcome: "Hello",
        goodbye: "Bye"
      }
    }

    result = @service.traverse(input, @translate_callback)

    assert_equal "HELLO", result[:messages][:welcome]
    assert_equal "BYE", result[:messages][:goodbye]
  end

  # Test array traversal
  speed_profile :fast
  test "should traverse arrays" do
    input = [ "first", "second", "third" ]

    result = @service.traverse(input, @translate_callback)

    assert_equal [ "FIRST", "SECOND", "THIRD" ], result
  end

  speed_profile :fast
  test "should traverse array of hashes" do
    input = [
      { text: "hello" },
      { text: "world" }
    ]

    result = @service.traverse(input, @translate_callback)

    assert_equal "HELLO", result[0][:text]
    assert_equal "WORLD", result[1][:text]
  end

  # Test hash with translation_hash marker
  speed_profile :fast
  test "should handle hash with translation_hash marker" do
    input = {
      translation_hash: true,
      text: "hello world"
    }

    # Use a callback that checks the context properties
    callback = ->(context) do
      assert_equal "hello world", context.text
      assert_equal "Spanish", context.target_lang
      assert_equal "en", context.source_lang
      assert_equal "formal", context.formality
      context.text.upcase
    end

    result = @service.traverse(input, callback)
    assert_equal "HELLO WORLD", result
  end

  speed_profile :fast
  test "should handle translation_hash with custom properties" do
    input = {
      translation_hash: true,
      text: "bonjour",
      target_lang: "English",
      source_lang: "fr",
      formality: "less"
    }

    callback = ->(context) do
      assert_equal "bonjour", context.text
      assert_equal "English", context.target_lang
      assert_equal "fr", context.source_lang
      assert_equal "less", context.formality
      context.text.upcase
    end

    result = @service.traverse(input, callback)
    assert_equal "BONJOUR", result
  end

  speed_profile :fast
  test "should raise error if translation_hash node missing text" do
    input = {
      translation_hash: true,
      target_lang: "Spanish"
    }

    assert_raises(ArgumentError) do
      @service.traverse(input, @translate_callback)
    end
  end

  # Test context path building
  speed_profile :fast
  test "should build context path for nested structures" do
    input = {
      notifications: {
        messages: {
          welcome: "Hello"
        }
      }
    }

    callback = ->(context) do
      if context.text == "Hello"
        assert_equal "notifications.messages.welcome", context.context
      end
      context.text.upcase
    end

    @service.traverse(input, callback)
  end

  speed_profile :fast
  test "should build context path with array indices" do
    input = {
      items: [ "first", "second" ]
    }

    contexts_seen = []
    callback = ->(context) do
      contexts_seen << context.context
      context.text.upcase
    end

    @service.traverse(input, callback)

    assert_includes contexts_seen, "items.0"
    assert_includes contexts_seen, "items.1"
  end

  # Test pluralization patterns
  speed_profile :fast
  test "should handle i18n pluralization with nested hash" do
    input = {
      food: {
        amount_one: "{{count}} ounce",
        amount_other: "{{count}} ounces"
      }
    }

    result = @service.traverse(input, @translate_callback)

    assert_equal "{{COUNT}} OUNCE", result[:food][:amount_one]
    assert_equal "{{COUNT}} OUNCES", result[:food][:amount_other]
  end

  speed_profile :fast
  test "should handle i18n pluralization at root level" do
    input = {
      student_count_one: "{{count}} student",
      student_count_other: "{{count}} students"
    }

    result = @service.traverse(input, @translate_callback)

    assert_equal "{{COUNT}} STUDENT", result[:student_count_one]
    assert_equal "{{COUNT}} STUDENTS", result[:student_count_other]
  end

  # Test error handling
  speed_profile :fast
  test "should raise error for unexpected types" do
    input = 12345

    assert_raises(ArgumentError) do
      @service.traverse(input, @translate_callback)
    end
  end

  speed_profile :fast
  test "should raise error for nil" do
    input = nil

    assert_raises(ArgumentError) do
      @service.traverse(input, @translate_callback)
    end
  end

  # Test mixed structures
  speed_profile :fast
  test "should handle complex mixed structure" do
    input = {
      simple: "text",
      nested: {
        deep: "value"
      },
      array: [ "one", "two" ],
      custom: {
        translation_hash: true,
        text: "custom translation",
        formality: "less"
      }
    }

    result = @service.traverse(input, @translate_callback)

    assert_equal "TEXT", result[:simple]
    assert_equal "VALUE", result[:nested][:deep]
    assert_equal [ "ONE", "TWO" ], result[:array]
    assert_equal "CUSTOM TRANSLATION", result[:custom]
  end

  # Test that string keys are automatically symbolized
  speed_profile :fast
  test "should symbolize string keys from input" do
    input = {
      "greeting" => "hello",
      "farewell" => "goodbye"
    }

    result = @service.traverse(input, @translate_callback)

    # Keys should be symbols in output
    assert_equal "HELLO", result[:greeting]
    assert_equal "GOODBYE", result[:farewell]
  end
end
