# frozen_string_literal: true

# Service to extract and filter <think> tags from LLM responses.
# Separates reasoning content from final output for cleaner responses and potential training data.
class ThoughtExtractor
  # Pattern to match <think>...</think> blocks, including multiline content
  THINK_TAG_PATTERN = /<think>(.*?)<\/think>/m
  
  # Pattern to detect closing tag without opening (malformed output)
  ORPHAN_CLOSING_TAG_PATTERN = /^(.*?)<\/think>/m

  # Extracts and removes think tags from content.
  # Returns hash with filtered content and extracted thoughts.
  #
  # @param content [String] The LLM response content
  # @return [Hash] { content: "filtered", thoughts: "extracted or nil" }
  def self.extract_and_filter(content)
    return { content: "", thoughts: nil } if content.nil? || content.empty?

    thoughts = []
    filtered_content = content.dup

    # First, extract properly paired think blocks
    content.scan(THINK_TAG_PATTERN) do |match|
      thoughts << match[0].strip if match[0]
    end

    # Remove properly paired think tags
    filtered_content.gsub!(THINK_TAG_PATTERN, "")

    # Handle orphan closing tags (reasoning before </think> without opening <think>)
    # This happens when LLM outputs reasoning without proper tag structure
    if filtered_content.include?("</think>") && !filtered_content.include?("<think>")
      if filtered_content =~ ORPHAN_CLOSING_TAG_PATTERN
        orphan_reasoning = $1
        if orphan_reasoning && !orphan_reasoning.strip.empty?
          thoughts << orphan_reasoning.strip
        end
        # Remove everything up to and including the orphan closing tag
        filtered_content = filtered_content.sub(ORPHAN_CLOSING_TAG_PATTERN, "")
      end
    end

    # Clean up filtered content
    filtered_content = filtered_content.strip

    # Return thoughts as concatenated string or nil
    extracted_thoughts = thoughts.empty? ? nil : thoughts.join("\n\n")

    {
      content: filtered_content,
      thoughts: extracted_thoughts
    }
  rescue => e
    # If extraction fails, return original content with nil thoughts
    Rails.logger.warn("ThoughtExtractor failed: #{e.message}") if defined?(Rails)
    {
      content: content.to_s,
      thoughts: nil
    }
  end
end

