module Mensa
  class ColumnDsl
    include SharedDsl
    attr_reader :config

    def initialize(name, &)
      @config = {
        name: name,
        attribute: name,
        filter: nil,
        order: nil,
        sortable: true
      }
      instance_eval(&) if block_given?
    end

    option :sortable
    option :attribute
  end
end
