module Mensa
  class ColumnDsl
    include SharedDsl
    attr_reader :config

    def initialize(name, &)
      @config = {
        name: name,
        filter: nil,
        order: nil,
        sortable: true
      }
      instance_eval(&) if block_given?
    end

    def sortable(value)
      config[:sortable] = value
    end
  end
end
