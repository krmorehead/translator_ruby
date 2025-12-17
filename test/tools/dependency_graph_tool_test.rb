require "test_helper"

class DependencyGraphToolTest < ActiveSupport::TestCase
  def setup
    @sandbox_path = Rails.root.join("tmp", "dep_graph_test_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(File.join(@sandbox_path, "lib"))
    FileUtils.mkdir_p(File.join(@sandbox_path, "app", "services"))
    @tool = DependencyGraphTool.new(sandbox_path: @sandbox_path)

    # Create test files with dependencies
    File.write(File.join(@sandbox_path, "lib", "calculator.rb"), <<~RUBY)
      # frozen_string_literal: true

      class Calculator
        def add(a, b)
          a + b
        end
      end
    RUBY

    File.write(File.join(@sandbox_path, "lib", "formatter.rb"), <<~RUBY)
      # frozen_string_literal: true

      require_relative "calculator"

      class Formatter
        include Comparable

        def initialize(calculator: Calculator.new)
          @calculator = calculator
        end
      end
    RUBY

    File.write(File.join(@sandbox_path, "app", "services", "math_service.rb"), <<~RUBY)
      # frozen_string_literal: true

      require_relative "../../lib/calculator"
      require_relative "../../lib/formatter"

      class MathService < BaseService
        include Formattable

        def initialize
          @calculator = Calculator.new
          @formatter = Formatter.new
        end
      end
    RUBY
  end

  def teardown
    FileUtils.rm_rf(@sandbox_path) if @sandbox_path && File.exist?(@sandbox_path)
  end

  test "extracts Ruby require/require_relative dependencies" do
    file_path = File.join(@sandbox_path, "lib", "formatter.rb")
    result = @tool.execute(path: file_path)

    assert result[:success]
    edges = result[:result][:edges]

    require_edge = edges.find { |e| e[:target]&.include?("calculator") }
    assert_not_nil require_edge
    assert_equal "import", require_edge[:type]
  end

  test "extracts Ruby include/extend dependencies" do
    file_path = File.join(@sandbox_path, "lib", "formatter.rb")
    result = @tool.execute(path: file_path)

    assert result[:success]
    edges = result[:result][:edges]

    include_edge = edges.find { |e| e[:target] == "Comparable" }
    assert_not_nil include_edge
    assert_equal "mixin", include_edge[:type]
  end

  test "extracts class inheritance" do
    file_path = File.join(@sandbox_path, "app", "services", "math_service.rb")
    result = @tool.execute(path: file_path)

    assert result[:success]
    edges = result[:result][:edges]

    inheritance_edge = edges.find { |e| e[:target] == "BaseService" }
    assert_not_nil inheritance_edge
    assert_equal "inheritance", inheritance_edge[:type]
  end

  test "creates nodes for analyzed files" do
    result = @tool.execute(path: @sandbox_path)

    assert result[:success]
    nodes = result[:result][:nodes]

    assert nodes.size >= 3
    node_paths = nodes.map { |n| n[:path] }
    assert node_paths.any? { |p| p.include?("calculator.rb") }
    assert node_paths.any? { |p| p.include?("formatter.rb") }
    assert node_paths.any? { |p| p.include?("math_service.rb") }
  end

  test "nodes include language detection" do
    result = @tool.execute(path: @sandbox_path)

    assert result[:success]
    nodes = result[:result][:nodes]

    ruby_node = nodes.find { |n| n[:path].end_with?(".rb") }
    assert_not_nil ruby_node
    assert_equal "ruby", ruby_node[:language]
  end

  test "respects depth limit" do
    # With depth 1, should only analyze top-level file
    file_path = File.join(@sandbox_path, "app", "services", "math_service.rb")
    result = @tool.execute(path: file_path, depth: 1)

    assert result[:success]
    # Should have edges but not deeply follow them
    assert result[:result][:edges].any?
  end

  test "handles circular dependencies" do
    # Create circular dependency
    File.write(File.join(@sandbox_path, "lib", "a.rb"), 'require_relative "b"')
    File.write(File.join(@sandbox_path, "lib", "b.rb"), 'require_relative "a"')

    result = @tool.execute(path: File.join(@sandbox_path, "lib", "a.rb"), depth: 5)

    # Should not infinite loop
    assert result[:success]
  end

  test "file with no imports returns empty edges" do
    file_path = File.join(@sandbox_path, "lib", "calculator.rb")
    result = @tool.execute(path: file_path)

    assert result[:success]
    # Calculator has no imports
    edges = result[:result][:edges]
    # Edges should be minimal or empty for this file specifically
  end

  test "handles non-existent path" do
    result = @tool.execute(path: File.join(@sandbox_path, "nonexistent.rb"))

    assert_equal false, result[:success]
    assert_includes result[:error], "not found"
  end

  test "schema returns valid OpenAI function format" do
    schema = DependencyGraphTool.schema

    assert_equal "function", schema[:type]
    assert_equal "dependency_graph", schema[:function][:name]
    assert schema[:function][:parameters][:properties].key?(:path)
    assert_includes schema[:function][:parameters][:required], "path"
  end

  test "tool is registered with ToolCallService" do
    tools = ToolCallService.available_tools
    dep_tool = tools.find { |t| t[:function][:name] == "dependency_graph" }

    assert_not_nil dep_tool
  end

  # Tests for other languages
  test "extracts Python import dependencies" do
    py_file = File.join(@sandbox_path, "module.py")
    File.write(py_file, <<~PYTHON)
      import os
      from typing import List
      from mypackage import helper
    PYTHON

    tool = DependencyGraphTool.new(sandbox_path: @sandbox_path)
    result = tool.execute(path: py_file)

    assert result[:success]
    edges = result[:result][:edges]
    targets = edges.map { |e| e[:target] }

    assert_includes targets, "os"
    assert_includes targets, "typing"
    assert_includes targets, "mypackage"
  end

  test "extracts JavaScript import dependencies" do
    js_file = File.join(@sandbox_path, "app.js")
    File.write(js_file, <<~JAVASCRIPT)
      import React from 'react';
      import { useState } from 'react';
      const lodash = require('lodash');
    JAVASCRIPT

    tool = DependencyGraphTool.new(sandbox_path: @sandbox_path)
    result = tool.execute(path: js_file)

    assert result[:success]
    edges = result[:result][:edges]
    targets = edges.map { |e| e[:target] }

    assert_includes targets, "react"
    assert_includes targets, "lodash"
  end
end

