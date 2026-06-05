# frozen_string_literal: true

module Mensa
  # Represents a batch action that can be applied to multiple selected records.
  #
  # batch :archive do
  #   title "Archive"
  #   process { |records| records.update_all(archived: true) }
  # end
  class BatchAction
    include ConfigReaders

    defined_by Mensa::Config::BatchDsl

    attr_reader :name, :table

    def initialize(name, config:, table:)
      @name = name
      @table = table
      @config = config
    end

    config_reader :title
    config_reader :description
    config_reader :process, call: false
  end
end
