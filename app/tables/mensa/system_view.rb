# frozen_string_literal: true

module Mensa
  # Provide additional links at the end of the row, with an icon, link and a name
  #
  # action :delete do
  #   link { |contact| delete_contact_path(contact) }
  #   link_attributes "data-turbo-method" => "delete"
  #   icon "fa-xmark"
  # end
  class SystemView
    include ConfigReaders

    attr_reader :id, :config

    def initialize(id, config:, table:)
      @id = id
      @table = table
      @config = config
    end

    config_reader :name

    alias_method :data, :config
  end
end
