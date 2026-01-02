# frozen_string_literal: true

module Actions
  # Action to locate where a class, module, or method is defined.
  # Uses pattern matching to find definition sites in the codebase.
  class LocateDefinitionAction < BaseAction
    class << self
      def description
        "Find where a class, module, method, or constant is defined in the codebase"
      end

      def parameters
        {
          symbol: {
            type: :string,
            required: true,
            description: "The symbol name to locate (e.g., 'Calculator', 'process_data')"
          },
          type: {
            type: :string,
            required: false,
            description: "Type of definition: 'class', 'module', 'method', 'constant', or 'any'"
          }
        }
      end

      def category
        :discovery
      end
    end

    # Pattern templates for different definition types
    DEFINITION_PATTERNS = {
      class: /^\s*class\s+%{symbol}\b/,
      module: /^\s*module\s+%{symbol}\b/,
      method: /^\s*def\s+(self\.)?%{symbol}\b/,
      constant: /^\s*%{symbol}\s*=/
    }.freeze

    # Execute the definition search
    # @param symbol [String] The symbol to locate
    # @param type [String] The type of definition to find
    # @return [Hash] Search results with definition locations
    def execute(symbol:, type: "any")
      return error_result("Symbol cannot be empty") if symbol.strip.empty?

      valid_types = %w[class module method constant any]
      return error_result("Invalid type: #{type}") unless valid_types.include?(type)

      definitions = find_definitions(symbol, type)

      if definitions.empty?
        # Try fuzzy search
        definitions = fuzzy_search(symbol, type)
      end

      # Record findings
      definitions.each do |defn|
        record_discovered_file(
          file_path: defn[:file],
          relevance: defn[:relevance],
          reasoning: "Contains #{defn[:type]} definition of '#{symbol}'"
        )

        record_finding(
          text: "#{defn[:type].capitalize} '#{symbol}' defined at #{defn[:file]}:#{defn[:line]}",
          source: defn[:file],
          confidence: defn[:confidence],
          metadata: { definition_type: defn[:type], line: defn[:line] }
        )
      end

      if definitions.any?
        result_data = {
          definitions: definitions,
          count: definitions.size,
          symbol: symbol,
          requested_type: type,
          findings: [{
            text: "Found #{definitions.size} definition(s) of '#{symbol}'",
            source: "locate_definition"
          }]
        }
        success_result(result_data)
      else
        result_data = {
          definitions: [],
          count: 0,
          symbol: symbol,
          requested_type: type,
          findings: [{
            text: "Could not locate definition of '#{symbol}' in the codebase",
            source: "locate_definition"
          }]
        }
        success_result(result_data, summary: "No definition found for '#{symbol}'")
      end
    end

    
    def find_definitions(symbol, type)
      patterns = build_patterns(symbol, type)
      definitions = []

      list_files(nil, pattern: "**/*.rb").each do |file_path|
        content = read_file(file_path)

        content.each_line.with_index do |line, index|
          patterns.each do |pattern_type, pattern|
            if line =~ pattern
              definitions << {
                file: file_path,
                relative_file: file_path.sub("#{path}/", ""),
                line: index + 1,
                type: pattern_type,
                content: line.strip,
                relevance: calculate_relevance(file_path, symbol, pattern_type),
                confidence: 0.95
              }
            end
          end
        end
      end

      # Sort by relevance
      definitions.sort_by { |d| -d[:relevance] }
    end

    def build_patterns(symbol, type)
      # Escape special regex characters in symbol
      escaped_symbol = Regexp.escape(symbol)

      if type == "any"
        DEFINITION_PATTERNS.transform_values do |pattern|
          Regexp.new(pattern.source % { symbol: escaped_symbol })
        end
      else
        pattern = DEFINITION_PATTERNS[type.to_sym]
        raise ArgumentError, "No pattern for type: #{type}" unless pattern

        { type.to_sym => Regexp.new(pattern.source % { symbol: escaped_symbol }) }
      end
    end

    def fuzzy_search(symbol, type)
      # Try partial matches and case-insensitive search
      results = []

      # Search for the symbol anywhere in definition lines
      pattern = case type
                when "class" then /^\s*class\s+\w*#{Regexp.escape(symbol)}\w*/i
                when "module" then /^\s*module\s+\w*#{Regexp.escape(symbol)}\w*/i
                when "method" then /^\s*def\s+(self\.)?\w*#{Regexp.escape(symbol)}\w*/i
                else /^\s*(class|module|def)\s+\w*#{Regexp.escape(symbol)}\w*/i
                end

      list_files(nil, pattern: "**/*.rb").each do |file_path|
        content = read_file(file_path)

        content.each_line.with_index do |line, index|
          if line =~ pattern
            match_type = extract_definition_type(line)
            results << {
              file: file_path,
              relative_file: file_path.sub("#{path}/", ""),
              line: index + 1,
              type: match_type,
              content: line.strip,
              relevance: 0.6, # Lower relevance for fuzzy matches
              confidence: 0.7,
              fuzzy_match: true
            }
          end
        end
      end

      results.sort_by { |d| -d[:relevance] }.first(10)
    end

    def extract_definition_type(line)
      case line
      when /^\s*class\s+/ then :class
      when /^\s*module\s+/ then :module
      when /^\s*def\s+/ then :method
      else :unknown
      end
    end

    def calculate_relevance(file_path, symbol, type)
      base = 0.7
      filename = File.basename(file_path, ".rb").downcase
      symbol_lower = symbol.downcase

      # Boost if filename matches symbol
      base += 0.2 if filename.include?(symbol_lower) || symbol_lower.include?(filename)

      # Boost for class/module definitions over methods
      base += 0.1 if %i[class module].include?(type)

      [base, 1.0].min
    end
  end
end
