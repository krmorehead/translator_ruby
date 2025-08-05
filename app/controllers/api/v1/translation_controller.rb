class Api::V1::TranslationController < ApplicationController
  def translate
    begin
      # Get parameters
      doc_to_translate = params[:doc_to_translate]
      header_format = request.headers["Content-Type"]&.downcase || "application/json"
      export_format = params[:export_format] || "JSON"

      # Validate required parameters
      return render json: { error: "doc_to_translate is required" }, status: :bad_request if doc_to_translate.blank?

      # Use the translation service
      service = TranslationService.new
      result = service.translate_document(
        doc_content: doc_to_translate,
        input_format: header_format,
        export_format: export_format
      )

      # Return response with appropriate content type
      content_type = export_format.upcase == "JSON" ? "application/json" : "application/x-yaml"
      render plain: result, content_type: content_type

    rescue JSON::ParserError
      render json: { error: "Invalid JSON format" }, status: :bad_request
    rescue Psych::SyntaxError
      render json: { error: "Invalid YAML format" }, status: :bad_request
    rescue ArgumentError => e
      render json: { error: e.message }, status: :bad_request
    rescue StandardError => e
      Rails.logger.error "Translation error: #{e.message}"
      render json: { error: "Translation failed", details: e.message }, status: :internal_server_error
    end
  end
end
