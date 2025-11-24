require "test_helper"

class TranslationContextTest < ActiveSupport::TestCase
  test "should initialize with just text" do
    context = TranslationContext.new(text: "Hello world")
    
    assert_equal "Hello world", context.text
    assert_equal "en", context.source_lang
    assert_equal "formal", context.formality
    assert_nil context.model_type
    assert_nil context.target_lang
    assert_nil context.context
  end

  test "should initialize with custom properties" do
    context = TranslationContext.new(
      text: "Bonjour",
      target_lang: "en",
      source_lang: "fr",
      context: "greeting.hello",
      formality: "less"
    )
    
    assert_equal "Bonjour", context.text
    assert_equal "en", context.target_lang
    assert_equal "fr", context.source_lang
    assert_equal "greeting.hello", context.context
    assert_equal "less", context.formality
    assert_nil context.model_type
  end

  test "should have default values" do
    context = TranslationContext.new
    
    assert_equal "en", context.source_lang
    assert_equal "formal", context.formality
    assert_nil context.model_type
    assert_nil context.text
    assert_nil context.target_lang
    assert_nil context.context
  end

  test "should allow setting properties after initialization" do
    context = TranslationContext.new(text: "Original")
    
    context.text = "Modified"
    context.target_lang = "es"
    context.context = "messages.welcome"
    
    assert_equal "Modified", context.text
    assert_equal "es", context.target_lang
    assert_equal "messages.welcome", context.context
  end

  test "should handle all formality options" do
    formality_options = ["default", "more", "less", "prefer_more", "prefer_less", "formal"]
    
    formality_options.each do |formality|
      context = TranslationContext.new(text: "Test", formality: formality)
      assert_equal formality, context.formality
    end
  end

  test "should handle model_type as no-op for now" do
    context = TranslationContext.new(text: "Test", model_type: "custom_model")
    
    assert_equal "custom_model", context.model_type
  end
end

