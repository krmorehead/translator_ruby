FactoryBot.define do
  factory :hello_response, class: "Hash" do
    # Don't persist this since it's just a hash, not an ActiveRecord model
    skip_create

    # This allows us to use FactoryBot.build(:hello_response) to generate expected response data
    initialize_with do
      {
        "message" => "Hello World!",
        "status" => "success",
        "timestamp" => Time.current.iso8601(3),
        "version" => "1.0.0"
      }
    end
  end
end
