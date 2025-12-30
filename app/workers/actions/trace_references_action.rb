# frozen_string_literal: true

module Actions
  # Action to trace where a symbol is used/referenced in the codebase.
  # Complementary to LocateDefinitionAction - finds usages rather than definitions.
  class TraceReferencesAction < BaseAction
    class << self
      def description
        "Find where a class, method, or symbol is used throughout the codebase"
      end

      def parameters
        {
          symbol: {
            type: :string,
            required: true,
            description: "The symbol to trace (e.g., 'Calculator', 'process_data')"
          },
          exclude_definitions: {
            type: :boolean,
            required: false,
            description: "Exclude definition sites from results (default: true)"
          },
          limit: {
            type: :integer,
            required: false,
            description: "Maximum number of references to return (default: 30)"
          }
        }
      end

      def category
        :discovery
      end
    end

    # Execute the reference tracing
    # @param symbol [String] The symbol to trace
    # @param exclude_definitions [Boolean] Whether to exclude definition sites
    # @param limit [Integer] Maximum results
    # @return [Hash] Trace results with reference locations
    def execute(symbol:, exclude_definitions: true, limit: 30)
      return failure_result("Symbol cannot be empty") if symbol.strip.empty?

      references = find_references(symbol, exclude_definitions)

      # Group by file for better organization
      by_file = references.group_by { |r| r[:file] }

      # Record discovered files
      by_file.keys.each do |file_path|
        record_discovered_file(
          file_path: file_path,
          relevance: 0.6,
          reasoning: "Contains references to '#{symbol}'"
        )
      end

      # Record summary finding
      if references.any?
        record_finding(
          text: "'#{symbol}' is used in #{by_file.keys.size} files with #{references.size} total references",
          source: "trace_references",
          confidence: 0.9,
          metadata: { symbol: symbol, file_count: by_file.keys.size, reference_count: references.size }
        )
      end

      success_result(
        symbol: symbol,
        references: references.first(limit),
        total_count: references.size,
        file_count: by_file.keys.size,
        by_file: by_file.transform_values { |refs| refs.first(5) },
        findings: references.any? ? [{
          text: "'#{symbol}' is referenced in #{by_file.keys.size} files",
          source: "trace_references"
        }] : []
      )
    end

    
    def find_references(symbol, exclude_definitions)
      references = []
      escaped_symbol = Regexp.escape(symbol)

      # Build pattern to match the symbol
      # This matches word boundaries to avoid partial matches
      pattern = /\b#{escaped_symbol}\b/

      list_files(nil, pattern: "**/*.rb").each do |file_path|
        content = read_file(file_path)

        content.each_line.with_index do |line, index|
          next unless line =~ pattern

          # Skip definitions if requested
          if exclude_definitions
            next if line =~ /^\s*(class|module|def)\s+#{escaped_symbol}/
          end

          references << {
            file: file_path,
            relative_file: file_path.sub("#{path}/", ""),
            line: index + 1,
            content: line.strip,
            context_type: classify_usage(line, symbol),
            relevance: calculate_reference_relevance(line, symbol)
          }
        end
      end

      # Sort by relevance
      references.sort_by { |r| -r[:relevance] }
    end

    def classify_usage(line, symbol)
      case line
      when /#{Regexp.escape(symbol)}\.new/
        :instantiation
      when /#{Regexp.escape(symbol)}\.\w+/
        :method_call
      when /include\s+#{Regexp.escape(symbol)}/
        :include
      when /extend\s+#{Regexp.escape(symbol)}/
        :extend
      when /<\s*#{Regexp.escape(symbol)}/
        :inheritance
      when /:\s*#{Regexp.escape(symbol)}/
        :type_annotation
      when /require.*#{Regexp.escape(symbol)}/i
        :require
      else
        :reference
      end
    end

    def calculate_reference_relevance(line, symbol)
      base = 0.5

      # Boost for meaningful usages
      base += 0.2 if line =~ /#{Regexp.escape(symbol)}\.new/
      base += 0.1 if line =~ /#{Regexp.escape(symbol)}\.\w+/
      base += 0.15 if line =~ /(include|extend|prepend)\s+#{Regexp.escape(symbol)}/
      base += 0.2 if line =~ /<\s*#{Regexp.escape(symbol)}/

      [base, 1.0].min
    end
  end
end
