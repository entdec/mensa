# frozen_string_literal: true

module Mensa
  class ApplicationComponent < ViewComponent::Base
    include ViewComponent::Slotable
    include ActionView::Helpers::TranslationHelper
    include Satis::Concerns::ContextualTranslations

    attr_accessor :original_view_context
  end
end
