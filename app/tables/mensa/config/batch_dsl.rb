# frozen_string_literal: true

module Mensa::Config
  class BatchDsl
    include DslLogic

    option :title, default: -> { name.to_s.humanize }
    option :description, default: ""
    option :process, default: ->(records) {}

    delegate :t, to: :I18n
  end
end
