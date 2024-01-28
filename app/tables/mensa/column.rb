# frozen_string_literal: true

module Mensa
  class Column
    include ConfigReaders
    attr_reader :name, :table, :config

    def initialize(name, config:, table:)
      @name = name
      @table = table
      @config = config
    end

    config_reader :sortable?

    def sort_direction
      table.params[:order]&.[](name)
    end

    def next_sort_direction
      if sort_direction == "asc"
        "desc"
      elsif sort_direction == "desc"
        nil
      else
        "asc"
      end
    end

    def attribute
      config[:attribute] || name
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
