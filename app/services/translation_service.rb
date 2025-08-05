require "yaml"
require "json"
require "logger"
require "openai"
require "net/http"
require "uri"

class TranslationService
  def initialize(llm_url: nil, timeout: 30)
    @llm_url = llm_url || ENV["LLM_URL"] || "http://localhost:52003"
    @timeout = timeout
  end

  def translate_document(doc_content:, input_format:, export_format: "JSON")
    # Validate export format
    unless %w[JSON YAML].include?(export_format.upcase)
      raise ArgumentError, "export_format must be JSON or YAML"
    end

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
        response = client.completions(
          parameters: {
            model: "auto", # using llama-swap alias for automatic load balancing
            prompt: "Translate to English: #{text}\nEnglish:",
            max_tokens: 50,
            temperature: 0.1,
            stream: false
          }
        )

      # Extract translation from completions response
      translated = response.dig("choices", 0, "text")&.strip
      translated && !translated.empty? ? translated : text

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

  def build_translation_prompt(text)
    "Translate to English: #{text}\nEnglish:"
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
end
