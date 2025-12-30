# frozen_string_literal: true

require "test_helper"

class ProjectPlanOutputServiceTest < ActiveSupport::TestCase
  def setup
    @temp_dir = Rails.root.join("tmp", "project_plan_output_test_#{Process.pid}").to_s
    FileUtils.mkdir_p(@temp_dir)
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if File.exist?(@temp_dir)
  end

  test "creates project directory with date prefix" do
    service = ProjectPlanOutputService.new(
      project_name: "test_project",
      base_path: @temp_dir
    )

    service.write(
      file_references_content: "# File References",
      project_plan_content: "# Project Plan"
    )

    assert File.exist?(service.project_directory)
    assert_match(/\d{2}-\d{2}-\d{4}_test_project/, service.project_directory)
  end

  test "slugifies project name correctly" do
    service = ProjectPlanOutputService.new(
      project_name: "User Authentication Feature!",
      base_path: @temp_dir
    )

    assert_match(/_user_authentication_feature$/, service.project_directory)
  end

  test "writes file_references.md to correct location" do
    service = ProjectPlanOutputService.new(
      project_name: "test_project",
      base_path: @temp_dir
    )

    content = "# File References\n\nTest content"
    paths = service.write(
      file_references_content: content,
      project_plan_content: "# Plan"
    )

    assert File.exist?(paths[:file_references_path])
    assert_equal content, File.read(paths[:file_references_path])
  end

  test "writes project_plan.md to correct location" do
    service = ProjectPlanOutputService.new(
      project_name: "test_project",
      base_path: @temp_dir
    )

    content = "# Project Plan\n\nTest content"
    paths = service.write(
      file_references_content: "# Refs",
      project_plan_content: content
    )

    assert File.exist?(paths[:project_plan_path])
    assert_equal content, File.read(paths[:project_plan_path])
  end

  test "returns correct paths" do
    service = ProjectPlanOutputService.new(
      project_name: "my_project",
      base_path: @temp_dir
    )

    paths = service.write(
      file_references_content: "# Refs",
      project_plan_content: "# Plan"
    )

    assert_kind_of String, paths[:project_path]
    assert_kind_of String, paths[:file_references_path]
    assert_kind_of String, paths[:project_plan_path]
    assert paths[:file_references_path].end_with?("file_references.md")
    assert paths[:project_plan_path].end_with?("project_plan.md")
  end

  test "handles special characters in project name" do
    service = ProjectPlanOutputService.new(
      project_name: "Project #1: The @Beginning!",
      base_path: @temp_dir
    )

    paths = service.write(
      file_references_content: "# Refs",
      project_plan_content: "# Plan"
    )

    assert File.exist?(paths[:project_path])
    # Should not contain special characters
    refute_match(/[#@!:]/, File.basename(paths[:project_path]))
  end

  test "uses custom output_base when provided" do
    custom_output = File.join(@temp_dir, "custom", "output")
    service = ProjectPlanOutputService.new(
      project_name: "test_project",
      base_path: @temp_dir,
      output_base: custom_output
    )

    paths = service.write(
      file_references_content: "# Refs",
      project_plan_content: "# Plan"
    )

    assert paths[:project_path].start_with?(custom_output)
  end

  test "default output_base is docs/projects" do
    service = ProjectPlanOutputService.new(
      project_name: "test_project",
      base_path: @temp_dir
    )

    expected_base = File.join(@temp_dir, "docs", "projects")
    assert service.project_directory.start_with?(expected_base)
  end
end

