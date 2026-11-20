# frozen_string_literal: true

module Mensa::Config
  class BatchDsl
    include DslLogic

    option :title, default: -> { name.to_s.humanize }
    option :description, default: ""
    # Partial with the dialog's fields, rendered in Mensa's form before the action runs
    option :form
    # Message to confirm before the action runs, for actions without a form
    option :confirm
    # Whether the action is shown (and allowed), called with the table
    option :show, default: ->(table) { true }
    option :process, default: ->(records) {}

    delegate :t, to: :I18n
  end
end
