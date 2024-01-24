module Mensa
  class TableDsl
    include SharedDsl
    attr_reader :config

    def initialize(name, &)
      @config = {
        columns: []
      }
      instance_eval(&)
    end

    def column(name, &)
      config[:columns] << Mensa::ColumnDsl.new(name, &).config
    end

    def model(model_class)
      config[:model_class] = model_class
    end
  end
end