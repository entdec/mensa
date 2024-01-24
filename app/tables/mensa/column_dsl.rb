module Mensa
  class ColumnDsl
    include SharedDsl
    attr_reader :config

    def initialize(name, &block)
      @config = {
        name: name,
        filter: nil,
        order: nil
      }
      instance_eval(&block) if block_given?
    end
  end
end