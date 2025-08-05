require "yaml"
require "json"
require "logger"
require "openai"
require "net/http"
require "uri"

class TranslationService
  def initialize(llm_url: nil, timeout: 30, protected_strings: [])
    @llm_url = llm_url || ENV["LLM_URL"] || "http://localhost:52003"
    @timeout = timeout
    @protected_strings = protected_strings + ["Brightwheel"] # Always protect Brightwheel
  end

  def translate_document(doc_content:, input_format:, export_format: "JSON", protected_strings: [], target_language: "Spanish")
    # Validate export format
    unless %w[JSON YAML].include?(export_format.upcase)
      raise ArgumentError, "export_format must be JSON or YAML"
    end

    # Merge protected strings
    @current_protected_strings = @protected_strings + protected_strings
    @target_language = target_language

    # Parse input document
    parsed_doc = parse_document(doc_content, input_format)

    # Convert to YAML for processing
    yaml_doc = convert_to_yaml(parsed_doc)

    # Traverse and translate leaf nodes
    translated_doc = translate_yaml_tree(yaml_doc)

    # Convert to requested export format
    convert_to_export_format(translated_doc, export_format.upcase)
  end

  private

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

  def translate_yaml_tree(node, path = [])
    case node
    when Hash
      result = {}
      node.each do |key, value|
        result[key] = translate_yaml_tree(value, path + [ key ])
      end
      result
    when Array
      node.map.with_index do |value, index|
        translate_yaml_tree(value, path + [ index ])
      end
    else
      # This is a leaf node - translate it
      translate_text(node.to_s)
    end
  end

  def translate_text(text)
    return text if text.strip.empty?

    begin
      client = create_llm_client
      
      # Build system prompt for structured output
      system_prompt = build_system_prompt(@target_language || "Spanish", @current_protected_strings || @protected_strings)
      
      response = client.chat(
        parameters: {
          model: "auto",
          messages: [
            { role: "system", content: system_prompt },
            { role: "user", content: text }
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
                required: ["translation"],
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
        parsed_response["translation"] || text
      else
        text
      end

    rescue => e
      error_msg = "LLM translation error: #{e.message}\nBacktrace: #{e.backtrace.first(3).join("\n")}"
      if logger
        logger.error error_msg
      else
        puts error_msg  # For debugging in tests
      end
      # Return original text if translation fails
      text
    end
  end

  def create_llm_client
    OpenAI::Client.new(
      access_token: "not-needed", # llama.cpp doesn't validate this but ruby-openai requires it
      uri_base: @llm_url,
      request_timeout: @timeout
    )
  end

  def get_available_model
    @available_model ||= fetch_first_available_model
  end

  def get_random_available_model
    available_models = fetch_all_available_models
    available_models.sample || "phi4-mini-1" # fallback if no models found
  end

  def fetch_first_available_model
    available_models = fetch_all_available_models
    available_models.first || "phi4-mini-1" # fallback to a known working model
  end

  def fetch_all_available_models
    @all_available_models ||= begin
      # For llama-swap, we can use a generic model name that it will route automatically
      # Based on your config, use the first model from your group as a representative
      [ "phi4-mini-1" ] # llama-swap will handle distribution internally
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

  def logger
    @logger ||= defined?(Rails) ? Rails.logger : Logger.new(STDOUT)
  end

  def build_system_prompt(target_language, protected_strings)
    protected_list = protected_strings&.any? ? protected_strings.join(", ") : "Brightwheel"
    
    <<~PROMPT
      Translate text to #{target_language}.

      Rules:
      1. Always translate to #{target_language}
      2. Keep {variables} unchanged: {school_name}, {user_name}, etc.
      3. Keep these terms unchanged: #{protected_list}
      4. Return JSON: {"translation": "result"}

      Examples:
      "Hello" → {"translation": "Hola"}
      "{school_name} shared a form" → {"translation": "{school_name} compartió un formulario"}
      "Welcome to Brightwheel" → {"translation": "Bienvenido a Brightwheel"}
    PROMPT
  end
end
