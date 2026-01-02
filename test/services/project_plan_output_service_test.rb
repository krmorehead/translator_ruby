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
  speed_profile :fast
  test "creates project directory with date prefix" do
    service = ProjectPlanOutputService.new(
      project_name: "test_project",
      output_base: @temp_dir
    )

    service.write(
      file_references_content: "# File References",
      project_plan_content: "# Project Plan"
    )

    assert File.exist?(service.project_directory)
    assert_match(/\d{2}-\d{2}-\d{4}_test_project/, service.project_directory)
  end

  speed_profile :fast
  test "slugifies project name correctly" do
    service = ProjectPlanOutputService.new(
      project_name: "User Authentication Feature!",
      output_base: @temp_dir
    )

    assert_match(/_user_authentication_feature$/, service.project_directory)
  end

  speed_profile :fast
  test "writes file_references.md to correct location" do
    service = ProjectPlanOutputService.new(
      project_name: "test_project",
      output_base: @temp_dir
    )

    content = "# File References\n\nTest content"
    paths = service.write(
      file_references_content: content,
      project_plan_content: "# Plan"
    )

    assert File.exist?(paths[:file_references_path])
    assert_equal content, File.read(paths[:file_references_path])
  end

  speed_profile :fast
  test "writes project_plan.md to correct location" do
    service = ProjectPlanOutputService.new(
      project_name: "test_project",
      output_base: @temp_dir
    )

    content = "# Project Plan\n\nTest content"
    paths = service.write(
      file_references_content: "# Refs",
      project_plan_content: content
    )

    assert File.exist?(paths[:project_plan_path])
    assert_equal content, File.read(paths[:project_plan_path])
  end

  speed_profile :fast
  test "returns correct paths" do
    service = ProjectPlanOutputService.new(
      project_name: "my_project",
      output_base: @temp_dir
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

  speed_profile :fast
  test "handles special characters in project name" do
    service = ProjectPlanOutputService.new(
      project_name: "Project #1: The @Beginning!",
      output_base: @temp_dir
    )

    paths = service.write(
      file_references_content: "# Refs",
      project_plan_content: "# Plan"
    )

    assert File.exist?(paths[:project_path])
    # Should not contain special characters
    refute_match(/[#@!:]/, File.basename(paths[:project_path]))
  end

  speed_profile :fast
  test "uses custom output_base when provided" do
    custom_path = File.join(@temp_dir, "custom", "output")
    service = ProjectPlanOutputService.new(
      project_name: "test_project",
      output_base: custom_path
    )

    paths = service.write(
      file_references_content: "# Refs",
      project_plan_content: "# Plan"
    )

    assert paths[:project_path].start_with?(custom_path)
  end


end

