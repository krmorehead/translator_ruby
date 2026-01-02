# frozen_string_literal: true

# File-backed store for narrative memory broken into named sections.
# Each section can provide a Context instance for smart relevance filtering.
class MemoryStore
  DEFAULT_SECTIONS = Memories::Registry::ALL.each_with_object({}) do |klass, h|
    h[klass.section_name.to_sym] = klass.default.dup
  end.freeze

  attr_reader :path, :id

  def initialize(path:)
    @path = path
    @id = SecureRandom.uuid
    @sections = load_sections
    @section_contexts = {}
    
    # Register with context graph service
    ContextGraphService.instance.register_memory_store(self)
  end

  def list_sections
    @sections.keys
  end

  def get_section(name)
    @sections[name.to_sym]
  end

  def set_section(name, value)
    section_key = name.to_sym
    @sections[section_key] = value
    @section_contexts.delete(section_key)
    save!
    @sections[section_key]
  end

  # Update a section. If append is true, push an entry; otherwise replace the section content.
  def update_section(name:, content:, append: true)
    section_key = name.to_sym

    if append
      @sections[section_key] ||= []
      @sections[section_key] << content
    else
      @sections[section_key] = [content]
    end

    @section_contexts.delete(section_key)
    save!
    @sections[section_key]
  end

  def to_h
    @sections
  end

  # Record a state transition for worker/workflow tracking
  def record_state_transition(from:, to:, event:, source: nil, payload: {})
    @sections[:state_transitions] ||= []
    entry = {
      from: from,
      to: to,
      event: event,
      source: source,
      payload: payload,
      timestamp: Time.now.utc.iso8601
    }
    @sections[:state_transitions] << entry
    save!
    entry
  end

  # Get a Context instance for a specific section.
  # @param section [Symbol] Section name
  # @return [Contexts::BaseContext] Context for the section
  def context_for(section)
    section_key = section.to_sym
    return @section_contexts[section_key] if @section_contexts.key?(section_key)

    section_data = @sections[section_key]
    return Contexts::BaseContext.new unless section_data

    memory_class = Memories::Registry.for(section)
    context_class = memory_class&.context_class || Contexts::BaseContext

    # Convert section data to Entry objects
    entries = normalize_section_data_to_entries(section_data, section_key.to_s)
    
    context = context_class.from_section_data(entries, source: section_key.to_s)
    @section_contexts[section_key] = context
  end

  # Get a composite context with sub-contexts for each section.
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

  # Load a memory store from a file
  def self.load(path)
    new(path: path)
  end

  # File modified time - use for versioning instead of per-entry timestamps
  def last_modified
    return nil unless File.exist?(path)

    File.mtime(path)
  end

  
  def load_sections
    return deep_dup(DEFAULT_SECTIONS) unless File.exist?(path)

    data = JSON.parse(File.read(path), symbolize_names: true)
    DEFAULT_SECTIONS.merge(data)
  end

  def save!
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.pretty_generate(@sections))
  end

  def deep_dup(obj)
    Marshal.load(Marshal.dump(obj))
  end

  # Convert section data to Entry objects
  # @param data [Array, Hash, nil] Section data
  # @param source [String] Source identifier
  # @return [Array<Contexts::Entries::BaseEntry>] Array of Entry objects
  def normalize_section_data_to_entries(data, source)
    return [] unless data

    if data.is_a?(Array)
      # Array of items - convert each to Entry
      data.map do |item|
        if item.is_a?(Contexts::Entries::BaseEntry)
          item
        else
          # Create Entry from raw data
          content = item.is_a?(Hash) ? (item[:text] || item.to_s) : item.to_s
          Contexts::Entries::BaseEntry.new(
            content: content,
            topics: [],
            source: source,
            metadata: {}
          )
        end
      end
    elsif data.is_a?(Hash)
      # Single hash - wrap in Entry
      content = data[:text] || data.to_s
      [Contexts::Entries::BaseEntry.new(
        content: content,
        topics: [],
        source: source,
        metadata: {}
      )]
    else
      []
    end
  end
end
