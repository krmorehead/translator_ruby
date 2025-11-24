require "yaml"
require "json"
require "logger"
require "openai"
require "net/http"
require "uri"
require "iso639"

class TranslationService
  def initialize(llm_url: nil, timeout: 30, protected_strings: [], target_language: "es")
    @llm_url = llm_url || ENV["LLM_URL"]
    @timeout = timeout
    @protected_strings = protected_strings + [ "Brightwheel" ] # Always protect Brightwheel
    @target_language = convert_language_code_to_name(target_language)
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
  def translate_text(translation_context)
    return translation_context.text if translation_context.text.strip.empty?

    begin
      client = create_llm_client

      # Use target_lang from context if present, otherwise fall back to @target_language
      target_lang = translation_context.target_lang || @target_language

      # Build system prompt for structured output
      system_prompt = build_system_prompt(
        target_lang,
        @current_protected_strings || @protected_strings,
        translation_context.source_lang,
        translation_context.formality
      )

      response = client.chat(
        parameters: {
          model: ENV["LLM_MODEL"] || "qwen30b",
          messages: [
            { role: "system", content: system_prompt },
            { role: "user", content: translation_context.text }
          ],
          response_format: {
            type: "json_schema",
            json_schema: {
              name: "translation_response",
              strict: true,
              schema: {
                type: "object",
                properties: {
                  translation: {
                    type: "string",
                    description: "The translated text with preserved variables and protected terms"
                  }
                },
                required: [ "translation" ],
                additionalProperties: false
              }
            }
          },
          max_tokens: 20000,
          temperature: 0.1,
          stream: false
        }
      )

      # Extract translation from structured JSON response
      raw_content = response.dig("choices", 0, "message", "content")&.strip

      if raw_content && !raw_content.empty?
        parsed_response = JSON.parse(raw_content)
        parsed_response["translation"] || translation_context.text
      else
        translation_context.text
      end

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
    case format
    when "JSON"
      JSON.pretty_generate(data)
    when "YAML"
      data.to_yaml
    else
      raise ArgumentError, "Unsupported export format: #{format}"
    end
  end

  private

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

  def create_llm_client
    OpenAI::Client.new(
      access_token: "not-needed", # llama.cpp doesn't validate this but ruby-openai requires it
      uri_base: @llm_url,
      request_timeout: @timeout
    )
  end

  def logger
    @logger ||= defined?(Rails) ? Rails.logger : Logger.new(STDOUT)
  end

  def build_system_prompt(target_language, protected_strings, source_lang = nil, formality = nil)
    protected_list = protected_strings&.any? ? protected_strings.join(", ") : "Brightwheel"

    prompt = +"Translate text to #{target_language}."
    
    if source_lang
      prompt << " Source language: #{source_lang}."
    end
    
    if formality && formality != "default"
      prompt << " Use #{formality} formality level."
    end

    prompt << <<~RULES


      Rules:
      1. Always translate to #{target_language}
      2. Keep {variables} unchanged: {school_name}, {user_name}, etc.
      3. Keep these terms unchanged: #{protected_list}
      4. Return JSON: {"translation": "result"}

      Examples:
      "Hello" → {"translation": "Hola"}
      "{school_name} shared a form" → {"translation": "{school_name} compartió un formulario"}
      "Welcome to Brightwheel" → {"translation": "Bienvenido a Brightwheel"}
    RULES

    prompt
  end
end
