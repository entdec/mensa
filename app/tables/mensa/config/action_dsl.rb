# frozen_string_literal: true

module Mensa::Config
  class ActionDsl
    include DslLogic

    option :title, default: -> { name }
    option :icon
    option :show, default: ->(record) { true }
    option :link
    option :link_attributes, default: {}

    delegate :t, to: :I18n
  end
end
