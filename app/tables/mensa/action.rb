# frozen_string_literal: true

module Mensa
  # Provide additional links at the end of the row, with an icon, link and a name
  #
  # action :delete do
  #   link { |contact| delete_contact_path(contact) }
  #   link_attributes "data-turbo-method" => "delete"
  #   icon "fa-xmark"
  # end
  #
  # Or run a bit of code with the record, without a controller of your own:
  #
  # action :activate do
  #   process { |user| user.activate! }
  #   icon "fa-check"
  # end
  class Action
    include ConfigReaders

    defined_by Mensa::Config::ActionDsl

    attr_reader :name, :table

    def initialize(name, config:, table:)
      @name = name
      @table = table
      @config = config
    end

    def icon(record)
      if @config[:icon].is_a?(Proc)
        @config[:icon].call(record)
      else
        @config[:icon]
      end
    end

    config_reader :title
    config_reader :link, call: false
    config_reader :link_attributes
    config_reader :show, call: false
    config_reader :process, call: false

    def process?
      process.present?
    end
  end
end
