class TranslationTreeService
  def initialize(target_language:, protected_strings: [])
    @target_language = target_language
    @protected_strings = protected_strings
  end

  # Traverse a tree structure and translate leaf nodes
  # translation_callback should be a proc/lambda that accepts a TranslationContext
  # Keys are symbolized at entry for internal consistency
  def traverse(node, translation_callback, path = [])
    symbolized = deep_symbolize_keys(node)
    traverse_internal(symbolized, translation_callback, path)
  end

  private

  def deep_symbolize_keys(node)
    case node
    when Hash
      node.to_h { |k, v| [k.to_sym, deep_symbolize_keys(v)] }
    when Array
      node.map { |v| deep_symbolize_keys(v) }
    else
      node
    end
  end

  def traverse_internal(node, translation_callback, path)
    case node
    when Hash
      # Check if this is a leaf node with translation_hash marker
      if node[:translation_hash] == true
        # This is a leaf node - create TranslationContext from hash
        create_context_from_hash(node, path, translation_callback)
      else
        # This is a parent node - traverse its children
        result = {}
        node.each do |key, value|
          result[key] = traverse_internal(value, translation_callback, path + [ key ])
        end
        result
      end
    when Array
      # Traverse array elements
      node.map.with_index do |value, index|
        traverse_internal(value, translation_callback, path + [ index ])
      end
    when String
      # String leaf node - create simple TranslationContext
      create_context_from_string(node, path, translation_callback)
    else
      # Unexpected type - raise an error
      raise ArgumentError, "Unexpected node type: #{node.class}. Expected Hash, Array, or String."
    end
  end

  def create_context_from_string(text, path, translation_callback)
    context = TranslationContext.new(
      text: text,
      target_lang: @target_language,
      source_lang: "en",
      context: build_context_path(path),
      model_type: nil,
      formality: "formal"
    )

    translation_callback.call(context)
  end

  def create_context_from_hash(node, path, translation_callback)
    # Extract the text property (required)
    text = node[:text]
    raise ArgumentError, "translation_hash node must have 'text' property" unless text

    # Extract optional properties
    context = TranslationContext.new(
      text: text,
      target_lang: node[:target_lang] || @target_language,
      source_lang: node[:source_lang] || "en",
      context: node[:context] || build_context_path(path),
      model_type: node[:model_type],
      formality: node[:formality] || "formal"
    )

    translation_callback.call(context)
  end

  def build_context_path(path)
    return nil if path.empty?
    path.join(".")
  end
end

