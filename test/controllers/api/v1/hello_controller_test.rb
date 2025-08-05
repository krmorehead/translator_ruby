require "test_helper"

class Api::V1::HelloControllerTest < ActionDispatch::IntegrationTest
  def setup
    # Store the time before making the request for timestamp validation
    @request_time = Time.current
  end

  test "should get index" do
    get "/api/v1/hello/index"
    assert_response :success
  end

  test "should return JSON response" do
    get "/api/v1/hello/index"
    assert_equal "application/json; charset=utf-8", response.content_type
  end

  test "should return correct message" do
    get "/api/v1/hello/index"
    json_response = JSON.parse(response.body)
    assert_equal "Hello World!", json_response["message"]
  end

  test "should return success status" do
    get "/api/v1/hello/index"
    json_response = JSON.parse(response.body)
    assert_equal "success", json_response["status"]
  end

  test "should return correct version" do
    get "/api/v1/hello/index"
    json_response = JSON.parse(response.body)
    assert_equal "1.0.0", json_response["version"]
  end

  test "should return current timestamp" do
    get "/api/v1/hello/index"
    json_response = JSON.parse(response.body)
    
    # Parse the timestamp from response
    response_timestamp = Time.parse(json_response["timestamp"])
    
    # The timestamp should be within a reasonable range (5 seconds) of when we made the request
    time_difference = (response_timestamp - @request_time).abs
    assert time_difference < 5, "Timestamp should be within 5 seconds of request time"
  end

  test "should return all required fields" do
    get "/api/v1/hello/index"
    json_response = JSON.parse(response.body)
    
    required_fields = %w[message status timestamp version]
    required_fields.each do |field|
      assert json_response.key?(field), "Response should include #{field} field"
    end
  end

  test "should return only expected fields" do
    get "/api/v1/hello/index"
    json_response = JSON.parse(response.body)
    
    expected_fields = %w[message status timestamp version]
    assert_equal expected_fields.sort, json_response.keys.sort
  end

  test "should have consistent response structure across multiple requests" do
    3.times do
      get "/api/v1/hello/index"
      assert_response :success
      
      json_response = JSON.parse(response.body)
      assert_equal "Hello World!", json_response["message"]
      assert_equal "success", json_response["status"]
      assert_equal "1.0.0", json_response["version"]
      assert json_response["timestamp"].present?
    end
  end

  test "should return valid ISO 8601 timestamp format" do
    get "/api/v1/hello/index"
    json_response = JSON.parse(response.body)
    
    timestamp = json_response["timestamp"]
    
    # Should be able to parse as ISO 8601 format
    assert_nothing_raised do
      Time.parse(timestamp)
    end
    
    # Should match ISO 8601 format pattern
    iso8601_pattern = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z\z/
    assert_match iso8601_pattern, timestamp, "Timestamp should be in ISO 8601 format"
  end

  test "timestamp should be unique across requests" do
    get "/api/v1/hello/index"
    first_response = JSON.parse(response.body)
    first_timestamp = first_response["timestamp"]
    
    # Wait a small amount to ensure timestamp difference
    sleep(0.001)
    
    get "/api/v1/hello/index"
    second_response = JSON.parse(response.body)
    second_timestamp = second_response["timestamp"]
    
    assert_not_equal first_timestamp, second_timestamp, "Timestamps should be unique across requests"
  end

  test "should handle GET request method only" do
    # Test that GET works
    get "/api/v1/hello/index"
    assert_response :success
    
    # Test that other HTTP methods return appropriate responses
    post "/api/v1/hello/index"
    assert_response :not_found
    
    put "/api/v1/hello/index"
    assert_response :not_found
    
    delete "/api/v1/hello/index"
    assert_response :not_found
    
    patch "/api/v1/hello/index"
    assert_response :not_found
  end

  test "should return consistent response time" do
    response_times = []
    
    5.times do
      start_time = Time.current
      get "/api/v1/hello/index"
      end_time = Time.current
      
      assert_response :success
      response_times << (end_time - start_time)
    end
    
    # All response times should be under 1 second (reasonable for a simple endpoint)
    response_times.each do |time|
      assert time < 1, "Response time should be under 1 second, got #{time}"
    end
  end

  test "should return valid JSON that can be parsed" do
    get "/api/v1/hello/index"
    
    assert_nothing_raised do
      JSON.parse(response.body)
    end
  end

  test "should inherit from ApplicationController" do
    assert Api::V1::HelloController.ancestors.include?(ApplicationController)
  end

  test "should inherit from ActionController API" do
    assert ApplicationController.ancestors.include?(ActionController::API)
  end
end 