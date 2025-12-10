# frozen_string_literal: true

require "json"
require "fileutils"
require "time"
require_relative "memory_kinds"
require_relative "memories/registry"

# File-backed store for narrative memory broken into named sections.
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

    persist!
    @sections[section_key]
  end

  def to_h
    @sections
  end

  private

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
