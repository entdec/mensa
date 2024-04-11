# frozen_string_literal: true

module Mensa::Config
  class ActionDsl
    include DslLogic

    option :icon
    option :show, default: ->(record) { true }
    option :link
    option :link_attributes, default: {}
  end
end
