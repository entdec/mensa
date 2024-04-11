# frozen_string_literal: true

module Mensa
  # Provide additional links at the end of the row, with an icon, link and a name
  #
  # action :delete do
  #   link { |contact| delete_contact_path(contact) }
  #   link_attributes "data-turbo-method" => "delete"
  #   icon "fa-xmark"
  # end
  class Action
    include ConfigReaders
    attr_reader :name, :table, :config

    def initialize(name, config:, table:)
      @name = name
      @table = table
      @config = config
    end

    config_reader :link
    config_reader :link_attributes
    config_reader :icon
    config_reader :show
  end
end
