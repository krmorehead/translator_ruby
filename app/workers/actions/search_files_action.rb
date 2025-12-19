# frozen_string_literal: true

module Actions
  # Action to search for files matching a pattern in the codebase.
  # Useful for discovering relevant files based on filename or content.
  class SearchFilesAction < BaseAction
    class << self
      def description
        "Search for files in the codebase by filename pattern or content"
      end

      def parameters
        {
          pattern: {
            type: :string,
            required: true,
            description: "Search pattern (filename glob or content regex)"
          },
          search_type: {
            type: :string,
            required: false,
            description: "Type of search: 'filename' or 'content' (default: filename)"
          },
          file_types: {
            type: :array,
            required: false,
            description: "File extensions to include (e.g., ['rb', 'py'])"
          },
          limit: {
            type: :integer,
            required: false,
            description: "Maximum number of results (default: 20)"
          }
        }
      end

      def category
        :discovery
      end
    end

    # Execute the file search
    # @param pattern [String] Search pattern
    # @param search_type [String] 'filename' or 'content'
    # @param file_types [Array<String>] File extensions to include
    # @param limit [Integer] Maximum results
    # @return [Hash] Search results
    def execute(pattern:, search_type: "filename", file_types: nil, limit: 20)
      return failure_result("Pattern cannot be empty") if pattern.strip.empty?
      return failure_result("Invalid search_type") unless %w[filename content].include?(search_type)

      files = case search_type
              when "content"
                search_by_content(pattern, file_types, limit)
              else
                search_by_filename(pattern, file_types, limit)
              end

      # Record discovered files
      files.each do |file_info|
        record_discovered_file(
          file_path: file_info[:path],
          relevance: file_info[:relevance],
          reasoning: "Found via #{search_type} search for '#{pattern}'"
        )
      end

      success_result(
        files: files,
        count: files.size,
        pattern: pattern,
        search_type: search_type,
        findings: files.any? ? [{ text: "Found #{files.size} files matching '#{pattern}'", source: "search" }] : []
      )
    end

    private

    def search_by_filename(pattern, file_types, limit)
      # Build glob pattern
      glob = build_filename_glob(pattern, file_types)
      files = Dir.glob(File.join(path, glob)).select { |f| File.file?(f) }

      # Score and sort by relevance
      scored = files.map do |file_path|
        {
          path: file_path,
          relative_path: relative_path(file_path),
          relevance: calculate_filename_relevance(file_path, pattern),
          type: :filename_match
        }
      end

      scored.sort_by { |f| -f[:relevance] }.first(limit)
    end

    def search_by_content(pattern, file_types, limit)
      file_glob = file_types ? "**/*.{#{file_types.join(',')}}" : "**/*"
      matches = grep_files(pattern, file_pattern: file_glob)

      # Group by file and calculate relevance
      by_file = matches.group_by { |m| m[:file] }

      results = by_file.map do |file_path, file_matches|
        {
          path: file_path,
          relative_path: relative_path(file_path),
          matches: file_matches.first(5), # Limit matches per file
          match_count: file_matches.size,
          relevance: calculate_content_relevance(file_matches),
          type: :content_match
        }
      end

      results.sort_by { |f| -f[:relevance] }.first(limit)
    end

    def build_filename_glob(pattern, file_types)
      # If pattern looks like a glob, use it directly
      if pattern.include?("*") || pattern.include?("?")
        pattern
      elsif file_types
        "**/#{pattern}*.{#{file_types.join(',')}}"
      else
        "**/#{pattern}*"
      end
    end

    def calculate_filename_relevance(file_path, pattern)
      filename = File.basename(file_path).downcase
      pattern_lower = pattern.downcase.gsub(/[*?]/, "")

      # Exact match gets highest score
      return 1.0 if filename == pattern_lower || filename == "#{pattern_lower}.rb"

      # Filename starts with pattern
      return 0.9 if filename.start_with?(pattern_lower)

      # Filename contains pattern
      return 0.7 if filename.include?(pattern_lower)

      # Path contains pattern
      return 0.5 if file_path.downcase.include?(pattern_lower)

      0.3
    end

    def calculate_content_relevance(matches)
      # More matches = higher relevance (with diminishing returns)
      base_score = [matches.size / 10.0, 0.5].min + 0.5

      # Boost for matches in method/class definitions
      definition_matches = matches.count do |m|
        m[:content] =~ /\b(def|class|module)\s+/
      end

      boost = definition_matches * 0.1
      [base_score + boost, 1.0].min
    end

    def relative_path(file_path)
      file_path.sub("#{path}/", "")
    end
  end
end
