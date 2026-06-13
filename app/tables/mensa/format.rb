# frozen_string_literal: true

module Mensa
  # Represents a batch action that can be applied to multiple selected records.
  #
  # batch :archive do
  #   title "Archive"
  #   process { |records| records.update_all(archived: true) }
  # end
  class Format
    include ConfigReaders

    defined_by Mensa::Config::FormatDsl

    config_reader :format
    config_reader :time_zone

    def initialize(config:, column:)
      @column = column
      @config = self.class.definition.merge(config || {})
    end
  end
end
