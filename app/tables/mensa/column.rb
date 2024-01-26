# frozen_string_literal: true

module Mensa
  class Column
    attr_reader :table, :config

    def initialize(table, config)
      @table = table
      @config = config
    end

    def name
      @config[:name]
    end

    def attribute
      @config[:attribute] || name
    end

    def human_name
      if table.model < ActiveRecord::Base
        table.model.human_attribute_name name
      else
        name.to_s.humanize
      end
    end
  end
end
