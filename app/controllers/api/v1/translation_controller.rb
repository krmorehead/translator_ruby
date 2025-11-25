class Api::V1::TranslationController < ApplicationController
  def translate
    begin
      # Get parameters
      doc_to_translate = params[:doc_to_translate]
      header_format = request.headers["Content-Type"]&.downcase || "application/json"
      export_format = params[:export_format] || "JSON"
      target_language = params[:target_language] || "es" # Default to Spanish

      # Validate required parameters
      return render json: { error: "doc_to_translate is required" }, status: :bad_request if doc_to_translate.blank?

      # Use the translation service with target language
      service = TranslationService.new(target_language: target_language)
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

  def translate_text
    begin
      # Get required parameters
      text = params[:text]
      target_lang = params[:target_lang]

      # Validate required parameters
      return render json: { error: "text is required" }, status: :bad_request if text.blank?
      return render json: { error: "target_lang is required" }, status: :bad_request if target_lang.blank?

      # Get optional parameters with defaults
      source_lang = params[:source_lang] || "en"
      context = params[:context]
      model_type = params[:model_type]
      formality = params[:formality] || "formal"

      # Create TranslationContext
      translation_context = TranslationContext.new(
        text: text,
        target_lang: target_lang,
        source_lang: source_lang,
        context: context,
        model_type: model_type,
        formality: formality
      )

      # Use the translation service
      service = TranslationService.new(target_language: target_lang)
      result = service.translate_text(translation_context)

      # Return translated text as JSON
      render json: { translation: result }, status: :ok

    rescue ArgumentError => e
      render json: { error: e.message }, status: :bad_request
    rescue StandardError => e
      Rails.logger.error "Translation error: #{e.message}"
      render json: { error: "Translation failed", details: e.message }, status: :internal_server_error
    end
  end
end
