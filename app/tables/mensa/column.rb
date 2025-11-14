# frozen_string_literal: true

module Mensa
  class Column
    include ConfigReaders

    defined_by Mensa::Config::ColumnDsl

    attr_reader :name, :table

    def initialize(name, config:, table:)
      @name = name
      @config = self.class.definition.merge(config || {})
      @table = table
    end

    config_reader :sortable?
    config_reader :sanitize?
    config_reader :visible?
    config_reader :internal?
    config_reader :method # When a method needs to be called on the model, slow!

    def sort_direction
      table.config.dig(:order, name)&.to_sym
    end

    def next_sort_direction
      if sort_direction == :asc
        :desc
      elsif sort_direction == :desc
        nil
      else
        :asc
      end
    end

    def attribute
      return @attribute if @attribute

      @attribute = if config[:attribute].present?
        "#{config[:attribute]} AS #{name}"
      elsif table.model.column_names.include? name.to_s
        name.to_s
      end
    end

    def attribute_for_condition
      return @attribute_for_condition if @attribute_for_condition

      @attribute_for_condition = if config[:attribute].present?
        config[:attribute]
      elsif table.model.column_names.include? name.to_s
        name.to_s
      end
    end

    # Returns true if the column supports filtering
    def filter?
      config.key?(:filter)
    end

    def filter
      return unless filter?

      @filter ||= Mensa::Filter.new(column: self, config: table.config.dig(:columns, name, :filter) || {}, table: table)
    end

    def human_name
      if table.model < ActiveRecord::Base
        table.model.human_attribute_name name
      else
        name.to_s.humanize
      end
    end

    def menu
      Satis::Menus::Builder.build(:filter_menu, event: "click") do |m|
        if sortable?
          m.item :sort_ascending, icon: "fa-solid fa-arrow-up-short-wide", link: table.path(order: {name => :asc}), link_attributes: {"data-turbo-frame": "_self"}
          m.item :sort_descending, icon: "fa-solid fa-arrow-down-wide-short", link: table.path(order: {name => :asc}), link_attributes: {"data-turbo-frame": "_self"}
        end
      end
    end
  end
end
