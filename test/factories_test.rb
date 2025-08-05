require "test_helper"

class FactoriesTest < ActiveSupport::TestCase
  # Note: User model doesn't exist yet, so this test is commented out
  # test "user factory should create valid user data" do
  #   user_data = build(:user)
  #   
  #   assert_equal "user@example.com", user_data.email
  #   assert_equal "Test User", user_data.name
  # end

  test "hello_response factory should generate valid response structure" do
    response_data = build(:hello_response)
    
    assert_equal "Hello World!", response_data["message"]
    assert_equal "success", response_data["status"]
    assert_equal "1.0.0", response_data["version"]
    assert response_data["timestamp"].present?
    
    # Verify timestamp is in ISO 8601 format
    assert_nothing_raised { Time.parse(response_data["timestamp"]) }
  end

  test "hello_response factory should generate valid timestamp format" do
    response_data = build(:hello_response)
    timestamp = response_data["timestamp"]
    
    # Should match ISO 8601 format pattern
    iso8601_pattern = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z\z/
    assert_match iso8601_pattern, timestamp, "Timestamp should be in ISO 8601 format"
  end

  test "factories should generate unique data across calls" do
    first_response = build(:hello_response)
    sleep(0.001) # Ensure timestamp difference
    second_response = build(:hello_response)
    
    # Timestamps should be different
    assert_not_equal first_response["timestamp"], second_response["timestamp"]
    
    # Other fields should be consistent
    assert_equal first_response["message"], second_response["message"]
    assert_equal first_response["status"], second_response["status"]
    assert_equal first_response["version"], second_response["version"]
  end
end 