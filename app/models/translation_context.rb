class TranslationContext
  attr_accessor :text, :target_lang, :source_lang, :context, :model_type, :formality

  def initialize(text: nil, target_lang: nil, source_lang: "en", context: nil, model_type: nil, formality: "formal")
    @text = text
    @target_lang = target_lang
    @source_lang = source_lang
    @context = context
    @model_type = model_type
    @formality = formality
  end
end

