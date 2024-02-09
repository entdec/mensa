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
    config_reader :sanitize?
    config_reader :method

    def sort_direction
      table.config.dig(:order, name)
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
      return @attribute if @attribute

      @attribute = if config[:attribute].to_s.downcase.include?(' as')
                     config[:attribute]
                   elsif config[:attribute].present?
                     "#{config[:attribute] || name} AS #{name}"
                   elsif table.model.column_names.include? name.to_s
                     name
                   else
                     nil
                   end
    end

    def visible?
      config[:visible]
    end

    def internal?
      config[:internal]
    end

    def human_name
      if table.model < ActiveRecord::Base
        table.model.human_attribute_name name
      else
        name.to_s.humanize
      end
    end

    def menu
      Satis::Menus::Builder.build(:filter_menu, event: 'click') do |m|
        if sortable?
          m.item :sort_ascending, icon: 'fa-solid fa-arrow-up-short-wide', link: table.path(order: { name => 'asc' }), link_attributes: { "data-turbo-frame": "_self" }
          m.item :sort_descending, icon: 'fa-solid fa-arrow-down-wide-short', link: table.path(order: { name => 'asc' }), link_attributes: { "data-turbo-frame": "_self" }
        end
      end
    end
  end
end
