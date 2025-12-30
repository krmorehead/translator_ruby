class TranslationService
  attr_reader :translation_context

  def initialize(llm_url: nil, timeout: 30, protected_strings: [], target_language: "es")
    @llm_url = llm_url || ENV["LLM_URL"]
    @timeout = timeout
    @protected_strings = protected_strings + [ "Brightwheel" ] # Always protect Brightwheel
    @target_language = convert_language_code_to_name(target_language)

    # Build a Contexts::TranslationContext for smart context management
    @translation_context = Contexts::TranslationContext.new(
      target_language: @target_language,
      source_language: "en",
      formality: "formal",
      protected_strings: @protected_strings
    )
  end

  def translate_document(doc_content:, input_format:, export_format: "JSON", protected_strings: [], target_language: nil)
    # Validate export format
    unless %w[JSON YAML].include?(export_format.upcase)
      raise ArgumentError, "export_format must be JSON or YAML"
    end

    # Override target language if provided in method call
    if target_language
      @target_language = convert_language_code_to_name(target_language)
    end

    # Merge protected strings
    @current_protected_strings = @protected_strings + protected_strings

    # Parse input document
    parsed_doc = parse_document(doc_content, input_format)

    # Convert to YAML for processing
    yaml_doc = convert_to_yaml(parsed_doc)

    # Traverse and translate leaf nodes using TranslationTreeService
    tree_service = TranslationTreeService.new(
      target_language: @target_language,
      protected_strings: @current_protected_strings
    )

    # Create a callback that calls translate_text
    translation_callback = ->(context) { translate_text(context) }

    translated_doc = tree_service.traverse(yaml_doc, translation_callback)

    # Convert to requested export format
    convert_to_export_format(translated_doc, export_format.upcase)
  end

  # Public methods for testing and external use
  # @param legacy_context [TranslationContext] Legacy context object with text, target_lang, etc.
  def translate_text(legacy_context)
    return legacy_context.text if legacy_context.text.strip.empty?

    begin
      # Use target_lang from context if present, otherwise fall back to @target_language
      target_lang = legacy_context.target_lang || @target_language

      # Update our smart TranslationContext with current settings
      @translation_context.target_language = target_lang
      @translation_context.source_language = legacy_context.source_lang
      @translation_context.formality = legacy_context.formality
      @translation_context.protected_strings = @current_protected_strings || @protected_strings

      prompt = TranslationPrompt.new(
        protected_strings: @current_protected_strings || @protected_strings,
        target_language: target_lang,
        source_language: legacy_context.source_lang,
        formality: legacy_context.formality,
        context_path: legacy_context.context
      )

      # Pass the smart TranslationContext to the prompt
      result = prompt.execute(
        prompt: legacy_context.text,
        context: @translation_context
      )

      # Record the translation for future context/consistency
      content = result[:content]
      translation = content[:translation] || legacy_context.text

      @translation_context.add_translation(
        source_text: legacy_context.text.truncate(100),
        translated_text: translation.truncate(100),
        context_path: legacy_context.context
      )

      translation
    rescue => e
      error_msg = "LLM translation error: #{e.message}\nBacktrace: #{e.backtrace.first(3).join("\n")}"
      if logger
        logger.error error_msg
      else
        puts error_msg  # For debugging in tests
      end
      # Re-raise the error so tests can see what's actually failing
      raise e
    end
  end

  def parse_document(doc, format_hint)
    return JSON.parse(doc) if format_hint&.include?("json")
    return YAML.safe_load(doc) if format_hint&.include?("yaml") || format_hint&.include?("yml")

    # Try to parse as JSON first, then YAML if that fails
    begin
      JSON.parse(doc)
    rescue JSON::ParserError
      YAML.safe_load(doc)
    end
  end

  def convert_to_yaml(data)
    if data.is_a?(String)
      # If it's already a string, try to parse it
      begin
        YAML.safe_load(data)
      rescue
        # If parsing fails, treat as plain text
        { "text" => data }
      end
    else
      data
    end
  end

  def convert_to_export_format(data, format)
    # Convert symbol keys to strings for external output
    stringified = deep_stringify_keys(data)
    case format
    when "JSON"
      JSON.pretty_generate(stringified)
    when "YAML"
      stringified.to_yaml
    else
      raise ArgumentError, "Unsupported export format: #{format}"
    end
  end

  def deep_stringify_keys(obj)
    case obj
    when Hash
      obj.to_h { |k, v| [k.to_s, deep_stringify_keys(v)] }
    when Array
      obj.map { |v| deep_stringify_keys(v) }
    else
      obj
    end
  end

  
  def convert_language_code_to_name(language_code)
    # Try to look up the language by code
    language_entry = Iso639[language_code]

    if language_entry
      language_entry.name
    else
      # Fall back to Spanish if lookup fails
      "Spanish"
    end
  end

  def logger
    @logger ||= defined?(Rails) ? Rails.logger : Logger.new(STDOUT)
  end
end
