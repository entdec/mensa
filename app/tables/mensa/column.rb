# frozen_string_literal: true

module Mensa
  class Column
    include ConfigReaders
    attr_reader :table, :config

    def initialize(table, config)
      @table = table
      @config = config
    end

    config_reader :name
    config_reader :attribute
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

    def human_name
      if table.model < ActiveRecord::Base
        table.model.human_attribute_name name
      else
        name.to_s.humanize
      end
    end
  end
end
