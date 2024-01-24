module Mensa
  class ColumnDsl
    include SharedDsl
    attr_reader :config

    def initialize(name, &)
      @config = {
        name: name,
        filter: nil,
        order: nil
      }
      instance_eval(&)
    end
  end
end