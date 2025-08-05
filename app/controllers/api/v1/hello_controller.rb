class Api::V1::HelloController < ApplicationController
  def index
    render json: {
      message: "Hello World!",
      status: "success",
      timestamp: Time.current,
      version: "1.0.0"
    }
  end
end
