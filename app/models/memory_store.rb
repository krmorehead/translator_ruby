# frozen_string_literal: true

# File-backed store for narrative memory broken into named sections.
# Each section can provide a Context instance for smart relevance filtering.
class MemoryStore
  DEFAULT_SECTIONS = Memories::Registry::ALL.each_with_object({}) do |klass, h|
    h[klass.section_name.to_sym] = klass.default.dup
  end.freeze

  attr_reader :path, :sandbox_path

  def initialize(path:, sandbox_path: nil)
    @path = path
    @sandbox_path = sandbox_path
    validate_sandbox_path!(path)
    @sections = load_sections
    @section_contexts = {}  # Cache for section contexts
  end

  def list_sections
    @sections.keys
  end

  def get_section(name)
    @sections[name.to_sym]
  end

  def set_section(name, value)
    section_key = name.to_sym
    raise ArgumentError, "Unknown section: #{name}" unless @sections.key?(section_key)
    @sections[section_key] = value
    @section_contexts.delete(section_key)  # Invalidate cached context
    persist!
    @sections[section_key]
  end

  # Update a section. If append is true, push an entry; otherwise replace the section content.
  def update_section(name:, content:, append: true)
    section_key = name.to_sym
    raise ArgumentError, "Unknown section: #{name}" unless @sections.key?(section_key)

    entry = normalize_entry(content)

    if append
      ensure_array_section!(section_key)
      @sections[section_key] << entry
    else
      @sections[section_key] = [ entry ]
    end

    @section_contexts.delete(section_key)  # Invalidate cached context
    persist!
    @sections[section_key]
  end

  def to_h
    @sections
  end

  # Get a Context instance for a specific section.
  # The Context is lazily created and cached.
  # @param section [String, Symbol] The section name
  # @return [Contexts::BaseContext] A context populated with section data
  def context_for(section)
    section_key = section.to_sym
    return @section_contexts[section_key] if @section_contexts.key?(section_key)

    memory_class = Memories::Registry.for(section)
    context_class = memory_class&.context_class || Contexts::BaseContext

    @section_contexts[section_key] = build_context(section_key, context_class)
  end

  # Get a composite context with sub-contexts for each section.
  # Useful for passing complete memory state to prompts.
  # @return [Contexts::BaseContext] A context with all sections as sub-contexts
  def full_context
    composite = Contexts::BaseContext.new

    @sections.each_key do |section_key|
      section_context = context_for(section_key)
      composite.add_sub_context(section_key, section_context)
    end

    composite
  end

  # Invalidate cached contexts (call after mutations)
  def invalidate_contexts!
    @section_contexts = {}
  end

  private

  # Build a context instance from section data
  # @param section_key [Symbol] The section key
  # @param context_class [Class] The context class to instantiate
  # @return [Contexts::BaseContext] The populated context
  def build_context(section_key, context_class)
    context = context_class.new
    section_data = @sections[section_key]

    populate_context_from_section(context, section_key, section_data)
    context
  end

  # Populate a context with data from a section
  # @param context [Contexts::BaseContext] The context to populate
  # @param section_key [Symbol] The section key (used for topics/source)
  # @param section_data [Array, String, Hash] The section data
  def populate_context_from_section(context, section_key, section_data)
    case section_data
    when Array
      section_data.each do |entry|
        add_entry_to_context(context, section_key, entry)
      end
    when String
      context.add(
        content: section_data,
        topics: [section_key.to_s],
        source: section_key.to_s
      )
    when Hash
      context.add(
        content: section_data[:text] || section_data["text"] || section_data.to_s,
        topics: [section_key.to_s],
        source: section_key.to_s,
        metadata: section_data
      )
    end
  end

  # Add a single entry to a context
  # @param context [Contexts::BaseContext] The context
  # @param section_key [Symbol] The section key
  # @param entry [Hash, String] The entry data
  def add_entry_to_context(context, section_key, entry)
    case entry
    when Hash
      content = entry[:text] || entry["text"] || entry[:content] || entry["content"] || entry.to_s
      topics = [section_key.to_s]

      # Add any tags from the entry as topics
      if entry[:tags]
        topics.concat(Array(entry[:tags]))
      end

      context.add(
        content: content,
        topics: topics,
        source: section_key.to_s,
        metadata: entry
      )
    when String
      context.add(
        content: entry,
        topics: [section_key.to_s],
        source: section_key.to_s
      )
    end
  end

  def load_sections
    return deep_dup(DEFAULT_SECTIONS) unless File.exist?(path)

    data = JSON.parse(File.read(path), symbolize_names: true) || {}
    DEFAULT_SECTIONS.merge(data) do |key, default_val, loaded|
      loaded || default_val || []
    end
  rescue JSON::ParserError
    deep_dup(DEFAULT_SECTIONS)
  end

  def persist!
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.pretty_generate(@sections))
  end

  def normalize_entry(content)
    if content.is_a?(Hash)
      content[:timestamp] ||= Time.now.utc.iso8601
      content
    else
      { text: content, timestamp: Time.now.utc.iso8601 }
    end
  end

  def ensure_array_section!(section_key)
    @sections[section_key] = [] unless @sections[section_key].is_a?(Array)
  end

  def deep_dup(obj)
    Marshal.load(Marshal.dump(obj))
  end

  def validate_sandbox_path!(file_path)
    return true unless sandbox_path

    expanded = File.expand_path(file_path)
    expanded_sandbox = File.expand_path(sandbox_path)
    unless expanded.start_with?(expanded_sandbox)
      raise SecurityError, "Path '#{file_path}' is outside the sandbox '#{sandbox_path}'"
    end
  end
end
